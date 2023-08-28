defmodule Bonfire.UI.Me.Plugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :plug

  alias Bonfire.Me.Users
  # alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(
      conn,
      :current_user,
      Users.get_current(get_session(conn, :user_id), get_session(conn, :account_id))
    )
  end
end
