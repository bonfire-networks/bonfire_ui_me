defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceMembersLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :any
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil

  def mount(socket) do
    # TODO: pagination
    users = if(socket_connected?(socket), do: Bonfire.Me.Users.list_all(), else: [])

    # TODO: implement `Bonfire.Boundaries.Blocks.LiveHandler.update_many` so we don't do n+1 on these!
    users =
      Enum.map(users, fn user ->
        user
        |> Map.put(
          :ghosted_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(id(user), :ghost, :instance_wide)
        )
        |> Map.put(
          :silenced_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(id(user), :silence, :instance_wide)
        )
      end)

    {:ok, assign(socket, :users, users)}
  end

  # def update(assigns, socket) do
  # IO.inspect(assigns, label: "assigns")
  # current_user = current_user(assigns) || current_user(socket.assigns)
  # tab = e(assigns, :selected_tab, nil)

  # users = Bonfire.Me.Users.list(current_user)
  # count = Bonfire.Me.Users.maybe_count()

  #   {:ok,
  #    assign(
  #      socket,
  #      selected_tab: tab,
  #      ghosted_instance_wide?: nil,
  #      silenced_instance_wide?: nil,
  #      current_user: current_user,
  #      page_title:
  #        if(count,
  #          do: l("Users directory (%{total})", total: count),
  #          else: l("Users directory")
  #        ),
  #      page: "users",
  #      users: users
  #    )}
  # end
end
