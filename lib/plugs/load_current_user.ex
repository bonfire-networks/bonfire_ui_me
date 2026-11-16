defmodule Bonfire.UI.Me.Plugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :plug

  # alias Bonfire.Me.Users
  alias Bonfire.UI.Me.LivePlugs.LoadCurrentUser
  # alias Bonfire.Data.Identity.User

  def init(opts), do: opts

  @decorate time()
  def call(conn, opts)

  # current user is already in context
  def call(%{assigns: %{current_user: _}} = conn, _) do
    conn
  end

  def call(conn, opts) do
    conn = Plug.Conn.fetch_session(conn)

    case Plug.Conn.get_session(conn, :current_user_id) do
      nil ->
        # debug(get_session(conn), "no current_user_id in session")
        Bonfire.UI.Me.Plugs.LoadCurrentAccount.call(conn, opts)

      current_user_id ->
        # `true` forces a logout, `:deselect` only takes the user out of the session (see `Bonfire.Me.Users.LiveHandler.deselect_user_everywhere/1`)
        forced_out = Bonfire.Common.Cache.get!("force_logout:#{current_user_id}")

        user =
          if !forced_out,
            do:
              LoadCurrentUser.get_current(
                current_user_id,
                Plug.Conn.get_session(conn, :current_account_id)
              )

        cond do
          # a forced logout, or a session ended by a password change elsewhere (checked on the account that loads with the user: no extra query), signs out
          forced_out == true ||
              (user && Bonfire.UI.Me.Sudo.revoked?(conn, e(user, :account, nil))) ->
            conn
            |> Bonfire.UI.Common.Web.renew_session()
            # the session no longer has a login and `set_locale` skipped this request, so detect the locale from the browser as for a guest
            |> Bonfire.UI.Common.LivePlugs.Locale.detect_for_conn()
            |> assign(:current_user, nil)
            |> assign(:current_account, nil)

          # a user taken out of the session (eg. queued for deletion) or that no longer loads leaves the account signed in, to choose another profile
          is_nil(user) ->
            conn
            |> Plug.Conn.delete_session(:current_user_id)
            |> Bonfire.UI.Me.Plugs.LoadCurrentAccount.call(opts)
            |> assign(:current_user, nil)

          true ->
            # the `set_locale` plug skipped this request because the session has a user: now the user and their settings are loaded, set the locale from them, once
            Bonfire.UI.Common.LivePlugs.Locale.put_locale_for(
              user,
              Plug.Conn.get_session(conn, Bonfire.Common.Localise.fallback_session_key())
            )

            conn
            |> assign(:current_user, user)
            |> assign(:current_account, e(user, :account, nil))
        end
    end
  end
end
