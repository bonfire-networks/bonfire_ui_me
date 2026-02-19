defmodule Bonfire.UI.Me.Plugs.UserRequired do
  use Bonfire.UI.Common.Web, :plug
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  @decorate time()
  def call(conn, opts)

  def call(%{assigns: assigns} = conn, opts) do
    check(current_user(assigns), current_account(assigns), opts[:json], conn)
  end

  defp check(%User{}, _account, _, conn), do: conn

  defp check(_user, %Account{}, true = _json, conn) do
    conn
    |> put_status(401)
    |> json(%{"error" => l("You need to select which user profile to use from your account.")})
    |> halt()
  end

  defp check(_user, %Account{}, _, conn) do
    conn
    |> assign_flash(:info, l("You need to choose a user to see that page."))
    |> set_go_after()
    |> redirect_to(path(:switch_user) || "/switch-user/")
    |> halt()
  end

  defp check(_user, _, true = _json, conn) do
    conn
    |> put_status(401)
    |> json(%{"error" => l("You need to login first.")})
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
