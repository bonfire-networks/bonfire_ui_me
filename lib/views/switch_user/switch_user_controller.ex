defmodule Bonfire.UI.Me.SwitchUserController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.SwitchUserLive

  @doc "A listing of users in the account."
  def index(%{assigns: assigns} = conn, params) do
    conn = fetch_query_params(conn)
    index(assigns[:current_account_users], current_account(assigns), conn, params)
  end

  defp index([], _, conn, params) do
    conn
    |> assign_flash(:info, l("Hey there! Let's fill out your profile!"))
    |> redirect_to("#{path(:create_user)}#{copy_go(params)}")
  end

  defp index([_ | _] = users, _, conn, _params) do
    conn
    |> assign(
      :current_account_users,
      filter_empty(users, [])
      # |> Users.check_active!() # not needed since we check it in `Users.by_account!/1` after querying
      |> debug(
        "list of users for the account, unless one of them have been blocked instance-wide"
      )
    )
    |> assign(:go, go_query(conn))
    |> live_render(SwitchUserLive)
  end

  defp index(nil, %Account{} = account, conn, params),
    do: index(Users.by_account(account), account, conn, params)

  # TODO: optimise by just checking if a user exists

  defp index(nil, _account, _conn, _params) do
    error("Missing current_account")
    throw(:missing_current_account)
  end

  @doc "Switch to a user, if permitted."
  def show(conn, %{"id" => username} = params) do
    debug("lookup")

    Users.by_username_and_account(username, current_account_id(conn))
    |> show(conn, params)
  end

  defp show({:ok, %{id: user_id} = _user}, conn, params) do
    # maybe_apply(Bonfire.Boundaries.Users, :create_missing_boundaries, user)

    debug("ok to switch")

    conn
    |> put_session(:current_user_id, user_id)
    |> put_session(:live_socket_id, "socket_user:#{user_id}")
    # |> assign_flash(:info, l("Welcome back, %{name}!", name: greet(user)))
    |> redirect_to_previous_go(params, "/", "/switch-user")
  end

  defp show(error, conn, params) do
    error(error, "Wrong user, or was blocked by admin")

    conn
    |> assign_flash(
      :error,
      l("You can only identify as valid users in your account.")
    )
    |> redirect_to("#{path(:switch_user)}#{copy_go(params)}")
  end

  # defp greet(%{profile: %{name: name}}) when is_binary(name) do
  #   name
  # end

  # defp greet(%{character: %{username: username}}) when is_binary(username) do
  #   "@#{username}"
  # end

  # defp greet(_) do
  #   "stranger"
  # end
end
