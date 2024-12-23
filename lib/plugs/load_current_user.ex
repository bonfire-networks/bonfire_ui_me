defmodule Bonfire.UI.Me.Plugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :plug

  # alias Bonfire.Me.Users
  alias Bonfire.UI.Me.LivePlugs.LoadCurrentUser
  # alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  @decorate time()
  def call(conn, opts)

  # current user is already in context
  def call(%{assigns: %{current_user: _}} = conn, _) do
    conn
  end

  def call(conn, opts) do
    case get_session(conn, :current_user_id) do
      nil ->
        debug(get_session(conn), "no current_user_id in session")
        Bonfire.UI.Me.Plugs.LoadCurrentAccount.call(conn, opts)

      current_user_id ->
        assign(
          conn,
          :current_user,
          LoadCurrentUser.get_current(current_user_id, get_session(conn, :current_account_id))
        )
    end
  end
end
