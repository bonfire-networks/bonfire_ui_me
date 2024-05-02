defmodule Bonfire.UI.Me.DeletedController do
  use Bonfire.UI.Common.Web, :controller

  def user(conn, _) do
    conn
    |> Bonfire.Me.Users.LiveHandler.disconnect_user_session()
    |> render_view(type: l("user"))
  end

  def account(conn, _) do
    conn
    |> Bonfire.Me.Users.LiveHandler.disconnect_account_session()
    |> render_view(type: l("account"))
  end

  # def other(conn, %{"type"=>type}) do
  #   conn
  #   |> render_view(type: type)
  # end

  def other(conn, _) do
    conn
    |> render_view(type: nil)
  end

  def render_view(conn, params) do
    live_render(
      conn,
      Bonfire.UI.Me.DeletedLive,
      session: stringify_keys(params)
    )
  end
end
