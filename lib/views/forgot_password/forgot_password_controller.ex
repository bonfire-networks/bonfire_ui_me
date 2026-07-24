defmodule Bonfire.UI.Me.ForgotPasswordController do
  use Bonfire.UI.Common.Web, :controller
  require Logger
  alias Bonfire.UI.Me.ForgotPasswordLive
  alias Bonfire.UI.Me.LoginLive
  alias Bonfire.UI.Me.LoginController
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users

  def index(conn, %{"login_token" => login_token}) do
    conn = fetch_query_params(conn)
    go = conn.query_params["go"]

    # Stash `go` in the session as soon as we consume the emailed link, so it
    # survives the whole post-login flow — including the switch-user page, where
    # `redirect_to_previous_go` reads it back regardless of which profile is picked.
    conn = if is_binary(go) and go != "", do: set_go_after(conn, go), else: conn

    passwordless? = LoginLive.passwordless_only?()
    action = if passwordless?, do: :login, else: :change_password

    case Accounts.confirm_email(login_token, confirm_action: action) do
      {:ok, account} ->
        if passwordless?, do: magic_link_login(conn, account), else: change_pw(conn, account)

      {:error, _changeset} ->
        conn
        |> assign_flash(
          :error,
          l("This sign-in link is invalid or has expired. Please request a new one.")
        )
        |> live_render(ForgotPasswordLive)
    end
  end

  def index(conn, _), do: live_render(conn, ForgotPasswordLive)

  def create(conn, params) do
    data = Map.get(params, "forgot_password_fields", %{})
    email = Map.get(data, "email")
    # `go` rides as a top-level hidden field on the passwordless login form, so the
    # emailed link can send the user back to where they came from after signing in.
    go = Map.get(params, "go")

    maybe_run_login_email_providers(data)

    case request_email(data, go) do
      {:ok, _, _} ->
        live_render(conn, ForgotPasswordLive,
          session: %{"requested" => true, "email" => email, "go" => go}
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        # `request_confirm_email` adds `:form` errors like "not_found" /
        # "confirmation_disabled" when the email is unknown or otherwise can't
        # produce a link. Don't tell snoopers if someone has an account here
        # or not — show the same neutral success state as the {:ok,_,_} branch
        # whenever the form itself is otherwise valid.
        if neutral_form_error?(changeset) do
          live_render(conn, ForgotPasswordLive,
            session: %{"requested" => true, "email" => email, "go" => go}
          )
        else
          live_render(conn, ForgotPasswordLive, session: %{"form" => changeset, "go" => go})
        end

      {:error, :not_found} ->
        live_render(conn, ForgotPasswordLive,
          session: %{"requested" => true, "email" => email, "go" => go}
        )

      other ->
        error(other, "Unexpected result from forgot password flow")
        live_render(conn, ForgotPasswordLive, session: %{"error" => true, "go" => go})
    end
  end

  def form(params \\ %{}), do: Accounts.changeset(:forgot_password, params)

  # Treat any errors that are only on `:form` (e.g. "not_found",
  # "confirmation_disabled") as the neutral success case — the user typed a
  # syntactically valid email, we just won't actually email anyone. Validation
  # errors on the `:email` field (bad format, etc.) keep showing the form.
  defp neutral_form_error?(%Ecto.Changeset{errors: errors}) when errors != [] do
    Enum.all?(errors, fn {field, _} -> field == :form end)
  end

  defp neutral_form_error?(_), do: false

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
          Bonfire.UI.Me.LoginEmailProvider.ensure(email)

        account ->
          case Users.by_account(account) do
            [] -> Bonfire.UI.Me.LoginEmailProvider.reconcile(email, account)
            [_ | _] -> :ok
          end
      end
    end
  end

  defp magic_link_login(conn, account) do
    user =
      case Users.get_only_in_account(account) do
        {:ok, user} -> user
        _ -> nil
      end

    # `go` was stashed in the session in `index/2`, so `logged_in/4` (and the
    # switch-user / create-profile tails) all recover it via `redirect_to_previous_go`
    # — no need to thread it through the form here.
    LoginController.logged_in(account, user, conn, %{})
  end

  defp change_pw(conn, account) do
    conn
    |> put_session(:current_account_id, account.id)
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
