defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceMembersLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop show, :any, default: :local

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     assign(
       socket,
       if(socket_connected?(socket),
         do: list_users(e(assigns(socket), :show, :local)),
         else: [users: [], page_info: nil]
       )
     )}
  end

  def handle_event("load_more", attrs, socket) do
    %{page_info: page_info, users: users} = list_users(e(assigns(socket), :show, :local), attrs)

    {:noreply,
     socket
     |> assign(
       loaded: true,
       #  users: e(assigns(socket), :users, []) ++ users,
       users: users,
       page_info: page_info
     )}
  end

  def list_users(show, attrs \\ nil) do
    %{edges: users, page_info: page_info} =
      Bonfire.Me.Users.list_paginated(
        show: show,
        skip_boundary_check: true,
        paginate: input_to_atoms(attrs)
      )

    # TODO: implement `Bonfire.Boundaries.Blocks.LiveHandler.update_many` so we don't do n+1 on these!
    users =
      Enum.map(users, fn user ->
        user
        |> Map.put(
          :ghosted_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide)
        )
        |> Map.put(
          :silenced_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(user, :silence, :instance_wide)
        )
      end)

    %{
      show: show,
      users: users,
      page_info: page_info
    }
  end
end
