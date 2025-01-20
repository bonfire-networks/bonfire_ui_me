defmodule Bonfire.UI.Me.LivePlugs.AdminRequired do
  use Bonfire.UI.Common.Web, :live_plug
  # alias Bonfire.Data.Identity.User

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(_params, _session, socket), do: check(current_account(socket), socket)

  defp check(context, socket) do
    if Bonfire.Me.Accounts.is_admin?(context) do
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
