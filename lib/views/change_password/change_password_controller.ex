defmodule Bonfire.UI.Me.ChangePasswordController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ChangePasswordLive

  def index(conn, params) do
    # stash a return-to path (e.g. a destructive-action modal that sent the user here to set/reset a
    # password) so `changed/2` can send them back after saving; reuses the shared `:go` session flow
    conn
    |> maybe_set_go_after(params)
    |> live_render(ChangePasswordLive)
  end

  def create(conn, params) do
    current_account = current_account(conn)
    attrs = Map.get(params, "change_password_fields", params)

    case Accounts.change_password(current_account, attrs,
           # a passwordless / magic-link account has no current password to require, so setting one for
           # the first time skips the old-password check (same as coming from a reset link)
           resetting_password:
             get_session(conn, :resetting_password) ||
               !Accounts.account_has_password?(current_account)
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
    |> delete_session(:resetting_password)
    |> assign_flash(
      :info,
      l("You have now changed your password. We recommend saving it in a password manager app!")
    )
    # return to where the user came from (e.g. the delete/migrate modal) if a `go` was stashed, else home
    |> redirect_to_previous_go(%{}, path(:home), conn.request_path)
  end
end
