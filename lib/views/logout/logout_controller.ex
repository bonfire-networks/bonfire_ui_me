defmodule Bonfire.UI.Me.LogoutController do
  use Bonfire.UI.Common.Web, :controller

  def index(conn, _) do
    conn
    |> Bonfire.Me.Users.LiveHandler.disconnect_account_session()
    # |> assign_flash(:info, l("Logged out successfully. Until next time!"))
    |> redirect_to_previous_go(conn.query_params, path(:home), "/logout")
  end
end
