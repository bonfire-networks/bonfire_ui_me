defmodule Bonfire.UI.Me.LivePlugs.UserRequired do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  # alias Plug.Conn.Query

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(_params \\ nil, session \\ nil, socket) do
    check(current_user(socket.assigns), current_account(socket), session, socket)
  end

  defp check(%User{}, _account, _, socket), do: {:ok, socket}

  defp check(nil, _, session, socket) when is_map(session),
    do: Bonfire.UI.Me.LivePlugs.LoadCurrentUser.mount(session, socket) ~> mount()

  defp check(_, account, _, socket), do: no(account, socket)

  defp no(%Account{}, socket) do
    {:halt,
     socket
     |> assign_flash(:info, l("You need to choose a user to see that page."))
     |> redirect_to(path(:switch_user))}
  end

  defp no(_account, socket) do
    {:halt,
     socket
     |> assign_flash(:info, l("You need to log in to see that page."))
     |> redirect_to(path(:login))}
  end
end
