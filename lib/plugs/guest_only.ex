defmodule Bonfire.UI.Me.Plugs.GuestOnly do
  use Bonfire.UI.Common.Web, :plug

  def init(opts), do: opts

  def call(conn, opts) do
    conn = Bonfire.UI.Me.Plugs.LoadCurrentUser.call(conn, opts)

    if current_account_id(conn.assigns) || current_user_id(conn),
      do: redirect_authed(conn),
      else: conn
  end

  defp redirect_authed(conn) do
    conn = fetch_query_params(conn)
    user_id = current_user_id(conn)

    conn
    |> maybe_error()
    |> Bonfire.UI.Me.LoginController.redirect_after_auth(user_id, conn.query_params)
    |> halt()
  end

  defp maybe_error(%{request_path: path} = conn)
       when path in ["/login", "/remote_interaction"] do
    debug(path, "auth page visited while already logged in, redirecting")
    conn
  end

  defp maybe_error(%{request_path: path} = conn) do
    if String.starts_with?(path, ["/login", "/remote_interaction"]) do
      debug(path, "auth page visited while already logged in, redirecting")
      conn
    else
      error(conn.request_path, "Guest only plug: access denied")
      assign_flash(conn, :error, "That page is only accessible to guests.")
    end
  end
end
