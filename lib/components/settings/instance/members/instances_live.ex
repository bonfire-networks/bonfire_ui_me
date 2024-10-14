defmodule Bonfire.UI.Me.SettingsViewsLive.InstancesLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     assign(
       socket,
       if(socket_connected?(socket),
         do: list_instances(),
         else: [instances: [], page_info: nil]
       )
     )}
  end

  def handle_event("load_more", attrs, socket) do
    %{page_info: page_info, instances: instances} = list_instances(attrs)

    {:noreply,
     socket
     |> assign(
       loaded: true,
       #  instances: e(assigns(socket), :instances, []) ++ instances,
       instances: instances,
       page_info: page_info
     )}
  end

  def list_instances(attrs \\ nil) do
    %{edges: instances, page_info: page_info} =
      Bonfire.Federate.ActivityPub.Instances.list_paginated(
        skip_boundary_check: true,
        paginate: input_to_atoms(attrs)
      )

    # TODO: implement `Bonfire.Boundaries.Blocks.LiveHandler.update_many` so we don't do n+1 on these!
    instances =
      Enum.map(instances, fn user ->
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

    %{
      instances: instances,
      page_info: page_info
    }
  end
end
