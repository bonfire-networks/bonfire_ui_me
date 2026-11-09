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

    account = Accounts.get_current(current_account_id)

    # the `set_locale` plug skipped this request because the session has a login: with no user chosen (a session with a user gets their language from `LoadCurrentUser`) use the account's language, and with no account either detect it from the browser
    conn =
      cond do
        Plug.Conn.get_session(conn, :current_user_id) -> conn
        account -> Bonfire.UI.Common.LivePlugs.Locale.put_locale_for_account(conn, account)
        true -> Bonfire.UI.Common.LivePlugs.Locale.detect_for_conn(conn)
      end

    assign_global(conn, :current_account, account)
  end
end
