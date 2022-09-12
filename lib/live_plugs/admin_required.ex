defmodule Bonfire.UI.Me.LivePlugs.AdminRequired do
  use Bonfire.UI.Common.Web, :live_plug
  # alias Bonfire.Data.Identity.User

  def mount(_params, _session, socket), do: check(current_user(socket), socket)

  defp check(user, socket) do
    if e(user, :instance_admin, :is_instance_admin, nil) == true do
      {:ok, socket}
    else
      {:halt,
       socket
       |> assign_flash(
         :error,
         l("That page is only accessible to instance administrators.")
       )
       |> redirect_to(path(:login))}
    end
  end
end
