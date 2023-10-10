defmodule Bonfire.UI.Me.Plugs.AdminRequired do
  use Bonfire.UI.Common.Web, :plug
  # alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  def call(conn, _opts),
    do:
      check(
        conn.assigns[:__context__] || current_user(conn.assigns) || current_account(conn.assigns),
        conn
      )

  defp check(context, conn) do
    if Bonfire.Me.Accounts.is_admin?(context) do
      conn
    else
      e = l("That page is only accessible to instance administrators.")
      # debug(e)
      conn
      # |> clear_session()
      |> assign_flash(:error, e)
      |> redirect_to(path(:home))
      |> halt()
    end
  end
end
