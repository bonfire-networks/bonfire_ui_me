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
        if Bonfire.Common.Cache.get!("force_logout:#{current_user_id}") do
          conn
          |> Bonfire.UI.Common.Web.renew_session()
          # the session no longer has a login and `set_locale` skipped this request, so detect the locale from the browser as for a guest
          |> Bonfire.UI.Common.LivePlugs.Locale.detect_for_conn()
          |> assign(:current_user, nil)
          |> assign(:current_account, nil)
        else
          user =
            LoadCurrentUser.get_current(
              current_user_id,
              Plug.Conn.get_session(conn, :current_account_id)
            )

          # the `set_locale` plug skipped this request because the session has a user: now the user and their settings are loaded, set the locale from them, once
          # a session whose user cannot be loaded has nothing to take it from, so detect it from the browser
          conn =
            if user do
              Bonfire.UI.Common.LivePlugs.Locale.put_locale_for(
                user,
                Plug.Conn.get_session(conn, Bonfire.Common.Localise.fallback_session_key())
              )

              conn
            else
              Bonfire.UI.Common.LivePlugs.Locale.detect_for_conn(conn)
            end

          conn
          |> assign(:current_user, user)
          |> assign(:current_account, e(user, :account, nil))
        end
    end
  end
end
