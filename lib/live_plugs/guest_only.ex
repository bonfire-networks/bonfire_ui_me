defmodule Bonfire.UI.Me.Plugs.GuestOnly do
  use Bonfire.UI.Common.Web, :plug

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_account] || conn.assigns[:current_user],
      do: not_permitted(conn),
      else: conn
  end

  defp not_permitted(conn) do
    conn
    |> maybe_error()
    |> redirect(to: path(:dashboard) || path(:home))
    |> halt()
  end

  defp maybe_error(%{request_path: "/login"} = conn) do
    conn
  end

  defp maybe_error(conn) do
    assign_flash(conn, :error, "That page is only accessible to guests.")
  end
end
