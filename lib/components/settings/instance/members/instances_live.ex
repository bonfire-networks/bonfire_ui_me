defmodule Bonfire.UI.Me.SettingsViewsLive.InstancesLive do
  use Bonfire.UI.Common.Web, :stateful_component
  
  prop title, :string, default: nil

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    
    # Set page_title if title prop is provided
    if socket_connected?(socket) && e(assigns, :title, nil) do
      send_self(page_title: e(assigns, :title, nil))
    end

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
      Enum.map(instances, fn instance ->
        instance
        |> Map.put(
          :ghosted_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(instance, :ghost, :instance_wide)
        )
        |> Map.put(
          :silenced_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(instance, :silence, :instance_wide)
        )
      end)
      |> debug("innnstances")

    %{
      instances: instances,
      page_info: page_info
    }
  end
end
