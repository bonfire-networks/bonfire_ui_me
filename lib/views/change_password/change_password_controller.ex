defmodule Bonfire.UI.Me.ChangePasswordController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ChangePasswordLive

  def index(conn, _), do: live_render(conn, ChangePasswordLive)

  def create(conn, params) do
    current_account = current_account(conn)
    attrs = Map.get(params, "change_password_fields", params)

    case Accounts.change_password(current_account, attrs,
           resetting_password: get_session(conn, :resetting_password)
         ) do
      {:ok, account} ->
        changed(conn, account)

      {:error, :not_found} ->
        conn
        |> assign_flash(
          :error,
          l("Unable to change your password. Try entering your old password correctly...")
        )
        |> assign(:error, :not_found)
        |> live_render(ChangePasswordLive)

      {:error, changeset} ->
        conn
        |> assign_flash(
          :error,
          l("Unable to change your password. Try entering a longer password...")
        )
        |> assign(:error, :invalid)
        |> assign(:form, changeset)
        |> live_render(ChangePasswordLive)
    end
  end

  def form_cs(params \\ %{}), do: Accounts.changeset(:change_password, params)

  defp changed(conn, _account) do
    conn
    |> assign_flash(
      :info,
      l("You have now changed your password. We recommend saving it in a password manager app!")
    )
    |> redirect_to(path(:home))
  end
end
