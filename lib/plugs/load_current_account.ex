defmodule Bonfire.UI.Me.Plugs.LoadCurrentAccount do
  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Me.Accounts

  def init(opts), do: opts

  def call(%{assigns: %{current_account: _current_account}} = conn, _opts) do
    conn
  end

  def call(conn, _opts) do
    current_account_id =
      conn
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.get_session(:current_account_id)
      |> debug("current_account_id in session")

    assign_global(
      conn,
      :current_account,
      Accounts.get_current(current_account_id)
    )
  end
end
