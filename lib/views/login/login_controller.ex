defmodule Bonfire.UI.Me.LoginController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  # alias Bonfire.Me.Users
  alias Bonfire.UI.Me.LoginLive
  # alias Bonfire.Common.Utils
  import Untangle

  # GET only supports 'go'
  def index(conn, _) do
    conn = fetch_query_params(conn)

    if user_id =
         Plug.Conn.get_session(conn, :current_user_id) ||
           Plug.Conn.get_session(conn, :current_account_id) do
      # already logged in — redirect with embed token if needed
      redirect_after_auth(conn, user_id, conn.query_params)
    else
      paint(conn, form_cs(Map.take(conn.query_params, [:go, "go", "email_or_username"])))
    end
  end

  def create(conn, form) do
    params = Map.get(form, "login_fields") || form

    case attempt(conn, params, form) do
      {:ok, conn} ->
        conn

      {:error, changeset} ->
        warn(changeset, "Login attempt failed in #{Config.repo()}")
        paint(conn, changeset)

      _other when is_map(params) ->
        paint(conn, Accounts.changeset(:login, params))
    end
  end

  def attempt(conn, params, form \\ %{}) do
    # cs = Accounts.changeset(:login, params)
    case Accounts.login(params) do
      {:ok, account, user} ->
        {:ok, logged_in(account, user, conn, form)}

      other ->
        warn(other, "Login validation error")

        other
    end
  end

  def logged_in(account, user, conn, form \\ %{})

  # the user logged in via email and have more than one user in the
  # account, so we must show them the user switcher.
  def logged_in(%{id: account_id} = current_account, nil, conn, form) do
    info(account_id, "Account logged in")

    conn
    |> put_session(:current_account_id, account_id)
    |> assign(:current_account, current_account)
    |> put_session(:current_user_id, nil)
    |> put_session(:live_socket_id, "socket_account:#{account_id}")
    |> assign_flash(:info, l("Welcome back!"))
    # to support redirect after a POST
    |> Plug.Conn.put_status(303)
    |> redirect_to("#{path(:switch_user) || "/switch-user/"}#{copy_go(form)}")
  end

  # the user logged in via username, or they logged in via email and
  # we found there was only one user in the account, so we're going to
  # just send them straight to the homepage and avoid the user
  # switcher.
  def logged_in(%{id: account_id} = current_account, %{id: user_id} = current_user, conn, form) do
    info(account_id, "Account logged in")
    info(user_id, "Logged in as user")
    # maybe_apply(Bonfire.Boundaries.Scaffold.Users, :create_missing_boundaries, user)

    conn =
      conn
      |> put_session(:current_account_id, account_id)
      |> assign(:current_account, current_account)
      |> put_session(:current_user_id, user_id)
      # needed if we run oAuth logic instead of redirecting
      |> assign(:current_user, current_user)
      |> put_session(:live_socket_id, "socket_user:#{user_id}")

    # to support redirect after a POST
    conn
    |> Plug.Conn.put_status(303)
    |> redirect_after_auth(user_id, form)
  end

  def redirect_after_auth(conn, user_id, form) do
    # Ensure external `go` URLs are written to the session so go_where? allows the redirect.
    # For allowed iframe embed origins, also append a signed token for cross-origin auth.
    go = Plug.Conn.get_session(conn, :go) || e(form, "go", nil) || e(form, :go, nil)

    conn =
      if is_binary(go) and not String.starts_with?(go, "/") do
        go =
          if is_binary(user_id) and embed_allowed_origin?(go) do
            info(go, "Adding embed token for allowed iframe origin")
            token = Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken.sign(conn, user_id)
            sep = if String.contains?(go, "?"), do: "&", else: "?"
            go <> sep <> "bonfire_embed_token=" <> token
          else
            info({go, user_id}, "Skipping embed token (not an allowed origin or no user_id)")
            go
          end

        Plug.Conn.put_session(conn, :go, go)
      else
        conn
      end

    redirect_to_previous_go(
      conn,
      form,
      path(:dashboard) || path(:home) || "/dashboard",
      path(:login) || "/login"
    )
  end

  defp embed_allowed_origin?(url) do
    allowed = System.get_env("IFRAME_ALLOWED_ORIGINS", "")
    return_host = URI.parse(url).host

    result =
      allowed
      |> String.split()
      |> Enum.any?(fn origin ->
        parsed_host = URI.parse(origin).host
        # handle bare hostnames like "example.com" (no scheme) where URI.parse gives nil host
        origin_host = parsed_host || origin
        origin_host == return_host
      end)

    info({return_host, allowed, result}, "embed_allowed_origin? check")
    result
  end

  def form_cs(params \\ %{})
  def form_cs(params) when is_map(params), do: Accounts.changeset(:login, params)

  def paint(conn, changeset \\ form_cs()) do
    conn
    |> assign(:form, to_form(changeset))
    |> live_render(LoginLive)
  end
end
