defmodule Bonfire.UI.Me.Plugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :plug

  alias Bonfire.Me.Users
  # alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  def call(conn, opts) do
    case get_session(conn, :user_id) do
      nil ->
        Bonfire.UI.Me.Plugs.LoadCurrentAccount.call(conn, opts)

      user_id ->
        assign(
          conn,
          :current_user,
          Users.get_current(user_id, get_session(conn, :account_id))
        )
    end
  end
end
