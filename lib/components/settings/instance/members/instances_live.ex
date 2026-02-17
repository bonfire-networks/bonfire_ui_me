defmodule Bonfire.UI.Me.SettingsViewsLive.InstancesLive do
  use Bonfire.UI.Common.Web, :stateful_component
  alias Bonfire.Federate.ActivityPub.Instances

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
         else: [instances: [], page_info: nil, instances_metadata: %{}]
       )
     )}
  end

  def handle_event("load_more", attrs, socket) do
    %{page_info: page_info, instances: instances, instances_metadata: metadata} =
      list_instances(attrs)

    {:noreply,
     socket
     |> assign(
       loaded: true,
       instances: e(assigns(socket), :instances, []) ++ instances,
       instances_metadata: Map.merge(e(assigns(socket), :instances_metadata, %{}), metadata),
       page_info: page_info
     )}
  end

  def list_instances(attrs \\ nil) do
    %{edges: instances, page_info: page_info} =
      Instances.list_paginated(
        skip_boundary_check: true,
        paginate: input_to_atoms(attrs)
      )

    peer_ids = Enum.map(instances, & &1.id)

    # Batch query for user counts (single query instead of N+1)
    user_counts = Instances.count_users_by_peer_ids(peer_ids)

    # Batch query for last activity timestamps
    last_activities = Instances.last_activity_by_peer_ids(peer_ids)

    # TODO: implement `Bonfire.Boundaries.Blocks.LiveHandler.update_many` so we don't do n+1 on these!
    # For now, keep the existing block status computation
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
      |> debug("instances")

    # Build metadata map with counts and timestamps
    instances_metadata =
      Map.new(instances, fn instance ->
        {instance.id,
         %{
           user_count: Map.get(user_counts, instance.id, 0),
           last_activity: Map.get(last_activities, instance.id),
           first_seen: Map.get(instance, :inserted_at)
         }}
      end)

    %{
      instances: instances,
      instances_metadata: instances_metadata,
      page_info: page_info
    }
  end
end
