defmodule Bonfire.UI.Me.LivePlugs.AccountRequired do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.Account

  def mount(_params, _session, socket),
    do: check(current_account(socket), socket)

  defp check(%Account{}, socket), do: {:ok, socket}

  defp check(_, socket) do
    {:halt,
     socket
     |> assign_flash(:error, l("You need to log in to view that page."))
     |> redirect_to(path(:login))}
  end
end
