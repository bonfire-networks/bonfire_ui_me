defmodule Bonfire.UI.Me.Plugs.GuestOnly do
  use Bonfire.UI.Common.Web, :plug

  def init(opts), do: opts

  def call(conn, _opts) do
    if current_account(conn.assigns) || conn.assigns[:current_user],
      do: redirect_home(conn),
      else: conn
  end

  defp redirect_home(conn) do
    conn
    |> maybe_error()
    |> redirect_to(path(:dashboard) || path(:home))
    |> halt()
  end

  defp maybe_error(%{request_path: "/login"} = conn) do
    error("login page attempted while already logged in")
    conn
  end

  defp maybe_error(conn) do
    error(conn.request_path, "Guest only plug: access denied")
    assign_flash(conn, :error, "That page is only accessible to guests.")
  end
end
