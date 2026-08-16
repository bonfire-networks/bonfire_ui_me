defmodule Bonfire.UI.Me.Plugs.AdminRequired do
  @moduledoc """
  Halts unless the current account is an instance admin.

  Preloads `:instance_admin` before asking, for the reason described in `Bonfire.UI.Me.LivePlugs.AdminRequired`: `Bonfire.Me.Accounts.is_admin?/1` returns false for an unloaded assoc rather than preloading it, and the current-user query doesn't load it, so an account reached via `current_user` arrives without it and a genuine admin is rejected.

  The preloaded account is assigned back, so the rest of the request reuses it rather than discarding the query and paying for it again.
  """

  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Accounts

  def init(opts), do: opts

  def call(conn, _opts), do: check(current_account(conn.assigns), conn)

  defp check(%Account{} = account, conn) do
    account = repo().maybe_preload(account, :instance_admin)

    check(Accounts.is_admin?(account), assign(conn, :current_account, account))
  end

  defp check(nil, conn),
    do: check(Accounts.is_admin?(conn.assigns[:__context__] || current_user(conn.assigns)), conn)

  defp check(true, conn), do: conn

  defp check(_, conn) do
    conn
    |> assign_flash(:error, l("That page is only accessible to instance administrators."))
    |> redirect_to(path(:home))
    |> halt()
  end
end
