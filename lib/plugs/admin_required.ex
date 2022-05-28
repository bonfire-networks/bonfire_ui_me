defmodule Bonfire.UI.Me.Plugs.AdminRequired do

  use Bonfire.UI.Common.Web, :plug
  # alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  def call(conn, _opts), do: check(conn.assigns[:current_user], conn)

  defp check(user, conn) do
    if e(user, :instance_admin, :is_instance_admin, nil) == true do
      conn
    else
      e = l "That page is only accessible to instance administrators."
      # debug(e)
      conn
      |> clear_session()
      |> assign_flash(:error, e)
      |> redirect(to: path(:home))
      |> halt()
    end
  end

end
