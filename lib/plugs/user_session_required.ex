defmodule Bonfire.UI.Me.Plugs.UserSessionRequired do
  @moduledoc """
  Lightweight auth gate for hot endpoints (e.g. tag/@mention autocomplete on every keystroke):
  requires an authenticated user SESSION but does NOT load the full user struct from the DB
  (unlike `LoadCurrentUser` + `UserRequired`, which query the user and preload associations).

  It reads `:current_user_id` straight from the signed session and assigns only that (so downstream
  code can use `current_user_or_id/1`, which returns the id when the full user isn't loaded), or
  raises `Bonfire.Fail.Auth` (which the framework renders as a 401 JSON error or a login redirect
  depending on the request) when there's no authenticated user. Honours the `force_logout` cache.
  """
  use Bonfire.UI.Common.Web, :plug

  def init(opts), do: opts

  def call(conn, opts)

  # full user already loaded upstream — nothing to do
  def call(%{assigns: %{current_user: %{id: _}}} = conn, _opts), do: conn

  def call(conn, _opts) do
    case conn |> Plug.Conn.fetch_session() |> Plug.Conn.get_session(:current_user_id) do
      current_user_id when is_binary(current_user_id) ->
        if Bonfire.Common.Cache.get!("force_logout:#{current_user_id}"),
          do: raise(Bonfire.Fail.Auth, :needs_login),
          # assign just the id — no DB load/preloads
          else: assign(conn, :current_user_id, current_user_id)

      _ ->
        raise Bonfire.Fail.Auth, :needs_login
    end
  end
end
