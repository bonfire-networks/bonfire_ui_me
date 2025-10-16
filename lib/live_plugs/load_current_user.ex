defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.SwitchUserLive
  # alias Bonfire.Data.Identity.User

  @behaviour Bonfire.UI.Common.LivePlugModule

  # Helper to DRY assignment and optional loading, checks settings internally
  defp assign_current_user(socket, user) do
    account_id = e(user, :account, :id, nil)

    socket =
      assign_global(socket,
        current_user: user,
        current_user_id: id(user),
        current_account_id: account_id
      )

    {:ok, socket} =
      with {:ok, socket} <-
             Settings.get([Bonfire.Me.Users, :show_switch_users_inline], false,
               current_user: user
             ) &&
               Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers.mount(nil, %{}, socket) do
        {:ok, socket}
      else
        _ ->
          {:ok, socket}
      end

    with {:ok, socket} <-
           Bonfire.Common.Settings.get(
             [Bonfire.UI.Boundaries.MyCirclesLive, :show_circles_nav_open],
             true,
             current_user: user
           ) &&
             Bonfire.UI.Me.LivePlugs.LoadCurrentUserCircles.mount(nil, %{}, socket) do
      {:ok, socket}
    else
      _ ->
        {:ok, socket}
    end
  end

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  @decorate time()
  def mount(params \\ nil, session, socket)

  def mount(params, session, {:ok, socket} = _) do
    mount(params, session, socket)
  end

  def mount(_, _, %{assigns: %{__context__: %{current_user: user}}} = socket) do
    # current user is already in context
    assign_current_user(socket, user)
  end

  def mount(_, _, %{assigns: %{current_user: user}} = socket) do
    # the non-live plug already supplied the current user
    assign_current_user(socket, user)
  end

  def mount(_, %{"current_user_id" => user_id} = session, socket) when is_binary(user_id) do
    user =
      get_current(
        user_id,
        current_account_id(assigns(socket)) || session["current_account_id"]
      )

    assign_current_user(socket, user)
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, current_user: nil, current_user_id: nil)}
  end

  def get_current(user_id, account_id) do
    # if ProcessTree.get(:approach_to_current_user)==:cache do
    # Cache.get!("current_user:#{user_id}") ||
    #   Users.get_current(
    #     user_id,
    #     account_id
    #   )
    #   |> Cache.put("current_user:#{user_id}", ...)
    # else
    Users.get_current(
      user_id,
      account_id
    )

    # end
  end

  # def user_to_assign(%{id: id} = user) do
  #   info(if ProcessTree.get(:approach_to_current_user)==:user do
  #     user
  # else
  #      id
  #   end)
  # end
  # def user_to_assign(other), do: other
end
