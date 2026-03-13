defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.SwitchUserLive
  # alias Bonfire.Data.Identity.User

  import Bonfire.UI.Common.Timing

  @behaviour Bonfire.UI.Common.LivePlugModule

  # Helper to DRY assignment and optional loading, checks settings internally
  defp assign_current_user(socket, user) do
    time_section :lv_assign_current_user do
      account_id = e(user, :account, :id, nil)

      socket =
        assign_global(socket,
          current_user: user,
          current_user_id: id(user),
          current_account_id: account_id
        )

      # NOTE: disabled since we now show this in PersistentLive
      # {:ok, socket} =
      #   with {:ok, socket} <-
      #          Settings.get([Bonfire.Me.Users, :show_switch_users_inline], false,
      #            current_user: user
      #          ) &&
      #            Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers.mount(nil, %{}, socket) do
      #     {:ok, socket}
      #   else
      #     _ ->
      #       {:ok, socket}
      #   end

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
  end

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      if socket.assigns[:__loading_screen__] do
        {:cont, socket, layout: {Bonfire.UI.Common.LayoutView, :loading}}
      else
        {:cont, socket}
      end
    end
  end

  def mount(params \\ nil, session, socket)

  def mount(params, session, {:ok, socket} = _) do
    mount(params, session, socket)
  end

  def mount(_, _, %{assigns: %{__context__: %{current_user: user}}} = socket) do
    # current user is already in context
    maybe_assign_current_user(socket, user)
  end

  def mount(_, _, %{assigns: %{current_user: user}} = socket) do
    # the non-live plug already supplied the current user
    maybe_assign_current_user(socket, user)
  end

  def mount(_, %{"current_user_id" => user_id} = session, socket) when is_binary(user_id) do
    account_id = current_account_id(assigns(socket)) || session["current_account_id"]

    if socket_connected?(socket) || socket.assigns[:__loading_screen__] || Config.env() == :test do
      # Connected mount: full load

      user =
        time_section :lv_get_current_user do
          get_current(
            user_id,
            account_id
          )
        end

      assign_current_user(socket, user)
    else
      disconnected_mount(socket, user_id, account_id)
    end
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, current_user: nil, current_user_id: nil)}
  end

  defp maybe_assign_current_user(socket, user) do
    if socket_connected?(socket) || socket.assigns[:__loading_screen__] || Config.env() == :test do
      assign_current_user(socket, user)
    else
      disconnected_mount(socket, Enums.id(user), current_account_id(user))
    end
  end

  defp disconnected_mount(socket, user_id, account_id) do
    flood(
      "Disconnected mount: skips expensive work and shows loading screen until socket connects"
    )

    {:ok,
     assign_global(socket,
       current_user: nil,
       current_user_id: user_id,
       current_account_id: account_id,
       __loading_screen__: true
     )}
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
