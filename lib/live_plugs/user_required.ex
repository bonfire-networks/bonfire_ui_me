defmodule Bonfire.UI.Me.LivePlugs.UserRequired do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  # alias Plug.Conn.Query

  def mount(_params, _session, %{assigns: the} = socket) do
    check(e(the, :current_user, nil), e(the, :current_account, nil), socket)
  end

  defp check(%User{}, _account, socket), do: {:ok, socket}

  defp check(_user, %Account{}, socket) do
    {:halt,
     socket
     |> assign_flash(:info, l("You need to choose a user to see that page."))
     |> redirect_to(path(:switch_user))}
  end

  defp check(_user, _account, socket) do
    {:halt,
     socket
     |> assign_flash(:info, l("You need to log in to see that page."))
     |> redirect_to(path(:login))}
  end
end
