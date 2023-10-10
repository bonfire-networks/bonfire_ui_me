defmodule Bonfire.UI.Me.Plugs.UserRequired do
  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  def call(%{assigns: assigns} = conn, _opts) do
    check(current_user(assigns), current_account(assigns), conn)
  end

  defp check(%User{}, _account, conn), do: conn

  defp check(_user, %Account{}, conn) do
    conn
    |> assign_flash(:info, l("You need to choose a user to see that page."))
    |> set_go_after()
    |> redirect_to(path(:switch_user))
    |> halt()
  end

  defp check(_user, _account, conn) do
    conn
    |> clear_session()
    |> assign_flash(:info, l("You need to log in to see that page."))
    |> set_go_after()
    |> redirect_to(path(:login))
    |> halt()
  end
end
