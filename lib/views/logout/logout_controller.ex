defmodule Bonfire.UI.Me.LogoutController do

  use Bonfire.UI.Common.Web, :controller

  def index(conn, _) do
    conn
    |> delete_session(:account_id)
    |> clear_session()
    |> assign_flash(:info, l "Logged out successfully. Until next time!")
    |> redirect(to: path(:home))
    |> redirect_to_previous_go(conn.query_params, path(:login), "/logout")
  end

end
