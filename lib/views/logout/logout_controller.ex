defmodule Bonfire.UI.Me.LogoutController do
  use Bonfire.UI.Common.Web, :controller

  def index(%{assigns: assigns} = conn, _) do
    disconnect_sockets(assigns)

    conn
    |> delete_session(:current_user_id)
    |> delete_session(:current_account_id)
    |> clear_session()
    # |> assign_flash(:info, l("Logged out successfully. Until next time!"))
    |> redirect_to_previous_go(conn.query_params, path(:home), "/logout")
  end

  def disconnect_sockets(context) do
    # see https://hexdocs.pm/phoenix_live_view/security-model.html#disconnecting-all-instances-of-a-live-user
    case current_user_id(context) do
      nil ->
        case current_account_id(context) do
          nil ->
            warn("no user or account sockets found to broadcast the logout to")

          account_id ->
            Utils.maybe_apply(
            Bonfire.Web.Endpoint,
            :broadcast,
            ["socket_account:#{account_id}", "disconnect", %{}])
        end

      user_id ->
        Utils.maybe_apply(
        Bonfire.Web.Endpoint,
        :broadcast,
        ["socket_user:#{user_id}", "disconnect", %{}])
    end
  end
end
