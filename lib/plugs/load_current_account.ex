defmodule Bonfire.UI.Me.Plugs.LoadCurrentAccount do
  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Me.Accounts

  def init(opts), do: opts

  def call(%{assigns: %{current_account: _current_account}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    assign_global(
      conn,
      :current_account,
      Accounts.get_current(get_session(conn, :current_account_id))
    )
  end
end
