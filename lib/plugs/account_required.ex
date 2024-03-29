defmodule Bonfire.UI.Me.Plugs.AccountRequired do
  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Data.Identity.Account

  def init(opts), do: opts

  def call(conn, _opts), do: check(current_account(conn.assigns |> debug()), conn)

  defp check(%Account{}, conn), do: conn

  defp check(_, conn) do
    conn
    |> clear_session()
    |> set_go_after()
    |> assign_flash(:error, l("You need to log in first."))
    |> redirect_to(path(:login))
    |> halt()
  end
end
