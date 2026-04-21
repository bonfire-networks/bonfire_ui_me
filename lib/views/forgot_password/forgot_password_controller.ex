defmodule Bonfire.UI.Me.ForgotPasswordController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.UI.Me.ForgotPasswordLive
  alias Bonfire.UI.Me.LoginLive
  alias Bonfire.UI.Me.LoginController
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users

  def index(conn, %{"login_token" => login_token}) do
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

    maybe_run_login_email_providers(data)

    case request_email(data) do
      {:ok, _, _} ->
        conn
        |> assign_flash(
          :info,
          l(
            "Thanks for your request. If your email address is linked to an account here, a link should be on its way to you."
          )
        )
        |> live_render(ForgotPasswordLive, session: %{"requested" => true})

      {:error, :not_found} ->
        # don't tell snoopers if someone has an account here or not
        conn
        |> assign_flash(
          :info,
          l(
            "Thanks for your request. If your email address is linked to an account here, a link should be on its way to you."
          )
        )
        |> live_render(ForgotPasswordLive, session: %{"requested" => true})

      {:error, changeset} ->
        conn
        |> live_render(ForgotPasswordLive, session: %{"form" => changeset})

      other ->
        conn
        |> live_render(ForgotPasswordLive, session: %{"error" => other})
    end
  end

  def form(params \\ %{}), do: Accounts.changeset(:forgot_password, params)

  # In passwordless mode the same form requests a magic sign-in link; otherwise
  # it's the classic forgot-password flow. The pipeline is shared — only the
  # confirm_action (and thus the mail template) differs.
  defp request_email(data) do
    if LoginLive.passwordless_only?() do
      Accounts.request_confirm_email(form(data), confirm_action: :login)
    else
      Accounts.request_forgot_password(form(data))
    end
  end

  # Gives extensions (e.g. bonfire_ghost) a chance to bootstrap a local
  # account+user for an unknown email before the magic link is requested.
  # Neutral response either way — we never reveal whether the email exists.
  defp maybe_run_login_email_providers(data) do
    with email when is_binary(email) and email != "" <- Map.get(data, "email"),
         nil <- Accounts.get_by_email(email) do
      Bonfire.UI.Me.LoginEmailProviders.ensure(email)
    end
  end

  defp magic_link_login(conn, account) do
    user =
      case Users.get_only_in_account(account) do
        {:ok, user} -> user
        _ -> nil
      end

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
