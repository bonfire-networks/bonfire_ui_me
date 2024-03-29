defmodule Bonfire.UI.Me.ForgotPasswordController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.UI.Me.ForgotPasswordLive
  alias Bonfire.Me.Accounts

  def index(conn, %{"login_token" => login_token}) do
    case Accounts.confirm_email(login_token, confirm_action: :change_password) do
      {:ok, account} ->
        change_pw(conn, account)

      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(ForgotPasswordLive)
    end
  end

  def index(conn, _), do: live_render(conn, ForgotPasswordLive)

  def create(conn, params) do
    data = Map.get(params, "forgot_password_fields", %{})

    case Accounts.request_forgot_password(form(data)) do
      {:ok, _, _} ->
        conn
        |> assign(:requested, true)
        |> assign_flash(
          :info,
          l(
            "Thanks for your request. If your email address is linked to an account here, a reset email should be on its way to you."
          )
        )
        |> live_render(ForgotPasswordLive)

      {:error, :not_found} ->
        # don't tell snoopers if someone has an account here or not
        conn
        |> assign(:requested, true)
        |> assign_flash(
          :info,
          l(
            "Thanks for your request. If your email address is linked to an account here, a reset email should be on its way to you."
          )
        )
        |> live_render(ForgotPasswordLive)

      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(ForgotPasswordLive)

      other ->
        conn
        |> assign(:error, other)
        |> live_render(ForgotPasswordLive)
    end
  end

  def form(params \\ %{}), do: Accounts.changeset(:forgot_password, params)

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

    # |> redirect_to( path(:home))
  end
end
