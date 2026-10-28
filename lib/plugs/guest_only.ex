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

    # The embed "Sign in" link points at `/remote_interaction?...&url=<article>`, carrying the return-to
    # as `url` (mirrors `RemoteInteractionLive.mount`'s `go || url`). Honor it as `go` here too, so an
    # already-signed-in user is returned to the article (with an embed token, for allowed origins)
    # instead of being dumped on the dashboard — otherwise they can't get back to comment.
    # Only when the `url` is safe (a local path or an allowed embed origin) so `?url=` can't become an
    # open redirect for an authed user.
    params =
      case conn.query_params do
        %{"url" => url} = params when is_binary(url) and url != "" ->
          if String.starts_with?(url, "/") or
               Bonfire.UI.Me.LoginController.embed_allowed_origin?(url),
             do: Map.put_new(params, "go", url),
             else: params

        params ->
          params
      end

    conn
    |> maybe_error()
    |> redirect_authed(user_id, params)
    |> halt()
  end

  # Signed in to an account without a profile (eg. after a password reset): pages show it a "Sign in" button, which must lead to picking a profile, like `LoginController.logged_in/5` does, not back to the page it was clicked on.
  defp redirect_authed(conn, nil, params) do
    case go_after(conn) || params["go"] do
      "/account/" <> _ ->
        Bonfire.UI.Me.LoginController.redirect_after_auth(conn, nil, params)

      _ ->
        conn
        |> maybe_set_go_after(params)
        |> redirect_to(path(:switch_user) || "/switch-user/")
    end
  end

  defp redirect_authed(conn, user_id, params),
    do: Bonfire.UI.Me.LoginController.redirect_after_auth(conn, user_id, params)

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
