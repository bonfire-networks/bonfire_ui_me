defmodule Bonfire.UI.Me.ForgotPasswordController do
  use Bonfire.UI.Common.Web, :controller
  require Logger
  alias Bonfire.UI.Me.ForgotPasswordLive
  alias Bonfire.UI.Me.LoginLive
  alias Bonfire.UI.Me.LoginController
  alias Bonfire.UI.Me.LoginLinkController
  alias Bonfire.UI.Me.EmailLink
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users

  # Opening a password reset link only checks the token and shows a page. Its button (`redeem/2`) uses the token up, so a mail scanner opening the link can't. Sign-in links have their own page in `Bonfire.UI.Me.LoginLinkController`.
  def index(conn, %{"login_token" => login_token} = params) do
    if sign_in_link_on_old_path?() do
      LoginLinkController.show(conn, params)
    else
      case Accounts.check_confirm_token(login_token, confirm_action: :change_password) do
        :ok ->
          EmailLink.confirm_page(
            conn,
            "/login/forgot-password/" <> URI.encode_www_form(login_token),
            title: l("Reset your password"),
            intro: l("Press the button to choose a new password."),
            button: l("Choose a new password")
          )

        _ ->
          invalid_link(conn)
      end
    end
  end

  def index(conn, _), do: live_render(conn, ForgotPasswordLive)

  def redeem(conn, %{"login_token" => login_token} = params) do
    if sign_in_link_on_old_path?() do
      LoginLinkController.redeem(conn, params)
    else
      conn = EmailLink.stash_go(conn)
      # the initiating profile, restored after redemption when this account owns it
      as_user = conn.query_params["as_user"]

      case Accounts.confirm_email(login_token, confirm_action: :change_password) do
        {:ok, account} -> change_pw(conn, account, as_user)
        {:error, _} -> invalid_link(conn)
      end
    end
  end

  @doc "The page a link lands on when its token can't be used: the form to request a new one."
  def invalid_link(conn) do
    conn
    |> assign_flash(
      :error,
      l("This sign-in link is invalid or has expired. Please request a new one.")
    )
    |> live_render(ForgotPasswordLive)
  end

  # Sign-in links used to open here, before they got their own page. On a passwordless instance, every link that reaches this path was sent as a sign-in link, so hand it over. TODO: remove once those links have expired, a day after the release that introduced /login/email/:token.
  defp sign_in_link_on_old_path?, do: LoginLive.passwordless_only?()

  def create(conn, params) do
    data = submitted_fields(params)
    # `go` rides as a top-level hidden field on the passwordless login form, so the
    # emailed link can send the user back to where they came from after signing in.
    go = Map.get(params, "go")

    # the passwordless login form's "I have a password" button logs in with the password instead of emailing a link. A filled-in password counts too, because pressing Enter submits with the form's first button ("Send sign-in link").
    if params["login_with"] == "password" or
         (is_binary(data["password"]) and data["password"] != "") do
      LoginController.create(conn, %{
        "login_fields" => %{"email_or_username" => data["email"], "password" => data["password"]},
        "go" => go
      })
    else
      # shown back on the "check your inbox" screen: what the person typed, never the address found for a username
      typed = data["email"]

      case Accounts.email_for_sign_in_link(typed || "") do
        # an unknown username: the same screen as an unknown email, and nothing is sent
        nil -> requested(conn, typed, go)
        email -> request_link(conn, Map.put(data, "email", email), typed, go)
      end
    end
  end

  # The passwordless login form uses the login page's field names, so password managers treat it as a login form; the forgot-password page and the resend button use `forgot_password_fields`.
  defp submitted_fields(%{"login_fields" => %{} = fields}),
    do: %{"email" => fields["email_or_username"], "password" => fields["password"]}

  defp submitted_fields(params), do: Map.get(params, "forgot_password_fields", %{})

  defp request_link(conn, data, typed, go) do
    maybe_run_login_email_providers(data)

    case request_email(data, go) do
      {:ok, _, _} ->
        requested(conn, typed, go)

      {:error, %Ecto.Changeset{} = changeset} ->
        # `request_confirm_email` adds `:form` errors like "not_found" /
        # "confirmation_disabled" when the email is unknown or otherwise can't
        # produce a link. Don't tell snoopers if someone has an account here
        # or not — show the same neutral success state as the {:ok,_,_} branch
        # whenever the form itself is otherwise valid.
        if Bonfire.UI.Me.EmailLink.neutral_form_error?(changeset) do
          requested(conn, typed, go)
        else
          live_render(conn, ForgotPasswordLive, session: %{"form" => changeset, "go" => go})
        end

      {:error, :not_found} ->
        requested(conn, typed, go)

      other ->
        error(other, "Unexpected result from forgot password flow")
        live_render(conn, ForgotPasswordLive, session: %{"error" => true, "go" => go})
    end
  end

  defp requested(conn, typed, go) do
    live_render(conn, ForgotPasswordLive,
      session: %{"requested" => true, "email" => typed, "go" => go}
    )
  end

  def form(params \\ %{}), do: Accounts.changeset(:forgot_password, params)

  # In passwordless mode the same form requests a magic sign-in link; otherwise
  # it's the classic forgot-password flow. The pipeline is shared — only the
  # confirm_action (and thus the mail template) differs.
  defp request_email(data, go) do
    if LoginLive.passwordless_only?() do
      Accounts.request_confirm_email(form(data), confirm_action: :login, go: go)
    else
      Accounts.request_forgot_password(form(data))
    end
  end

  # Gives extensions a chance to bootstrap an unknown email or repair a profileless externally linked account before requesting its magic link. Accounts with profiles never consult external providers.
  defp maybe_run_login_email_providers(data) do
    with email when is_binary(email) and email != "" <- Map.get(data, "email") do
      case Accounts.get_by_email(email) do
        nil ->
          Bonfire.Me.LoginEmailProvider.ensure(email)

        account ->
          case Users.by_account(account) do
            [] -> Bonfire.Me.LoginEmailProvider.reconcile(email, account)
            [_ | _] -> :ok
          end
      end
    end
  end

  defp change_pw(conn, account, as_user \\ nil) do
    user = Users.get_in_account(as_user, account.id)

    conn
    # same lifecycle as logged_in/5: switching accounts clears the session (so no proof migrates), and redeeming the emailed token proves inbox control
    |> Bonfire.UI.Me.Sudo.renew_session_for(account.id)
    |> Bonfire.UI.Me.Sudo.stamp(:email)
    |> put_session(:current_account_id, account.id)
    |> then(&if(user, do: put_session(&1, :current_user_id, user.id), else: &1))
    # tell the change password form not to ask for the old password
    |> put_session(:resetting_password, true)
    |> assign_flash(
      :info,
      l(
        "Welcome back! Thanks for confirming your email address. You can now change your password."
      )
    )
    |> redirect_to(path(Bonfire.UI.Me.ChangePasswordController))
  end
end
