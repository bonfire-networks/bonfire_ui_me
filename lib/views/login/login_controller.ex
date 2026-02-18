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
    paint(conn, form_cs(Map.take(conn.query_params, [:go, "go", "email_or_username"])))
  end

  def create(conn, form) do
    params = Map.get(form, "login_fields") || form

    case attempt(conn, params, form) do
      {:ok, conn} ->
        conn

      {:error, changeset} ->
        warn(changeset, "Login attempt failed in #{Config.repo()}")
        paint(conn, changeset)

      _other ->
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

    conn
    |> put_session(:current_account_id, account_id)
    |> assign(:current_account, current_account)
    |> put_session(:current_user_id, user_id)
    # needed if we run oAuth logic instead of redirecting
    |> assign(:current_user, current_user)
    |> put_session(:live_socket_id, "socket_user:#{user_id}")
    # |> assign_flash(
    #   :info,
    #   l("Welcome back, %{name}!",
    #     name: e(user, :profile, :name, e(user, :character, :username, "anonymous"))
    #   )
    # )
    # to support redirect after a POST
    |> Plug.Conn.put_status(303)
    |> redirect_to_previous_go(form, "/", "/login")
  end

  def form_cs(params \\ %{}), do: Accounts.changeset(:login, params)

  def paint(conn, changeset \\ form_cs()) do
    conn
    |> assign(:form, to_form(changeset))
    |> live_render(LoginLive)
  end
end
