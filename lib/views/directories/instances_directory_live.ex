defmodule Bonfire.UI.Me.InstancesDirectoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.Federate.ActivityPub.Instances

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    current_user = current_user(socket)

    show_to =
      Bonfire.Common.Settings.get(
        [Bonfire.UI.Me.UsersDirectoryLive, :show_to],
        :users
      )

    if show_to ||
         maybe_apply(Bonfire.Me.Accounts, :is_admin?, [assigns(socket)[:__context__]],
           fallback_return: nil
         ) == true do
      if (show_to == :guests or current_user(socket)) || current_account(socket) do
        %{instances: instances, instances_metadata: instances_metadata, page_info: page_info} =
          list_instances(input_to_atoms(params))

        {:ok,
         assign(
           socket,
           page_title: l("Known fediverse instances"),
           page: "known_instances",
           selected_tab: :instances,
           instances: instances,
           instances_metadata: instances_metadata,
           page_info: page_info
         )}
      else
        throw(l("You need to log in before browsing the user directory"))
      end
    else
      throw(l("The user directory is disabled on this instance"))
    end
  end

  def handle_event("load_more", attrs, socket) do
    %{instances: instances, instances_metadata: metadata, page_info: page_info} =
      list_instances(input_to_atoms(attrs))

    {:noreply,
     socket
     |> assign(
       loaded: true,
       instances: e(assigns(socket), :instances, []) ++ instances,
       instances_metadata: Map.merge(e(assigns(socket), :instances_metadata, %{}), metadata),
       page_info: page_info
     )}
  end

  defp list_instances(attrs) do
    %{edges: instances, page_info: page_info} =
      Instances.list_paginated(attrs)

    peer_ids = Enum.map(instances, & &1.id)

    user_counts = Instances.count_users_by_peer_ids(peer_ids)
    last_activities = Instances.last_activity_by_peer_ids(peer_ids)

    instances_metadata =
      Map.new(instances, fn instance ->
        {instance.id,
         %{
           user_count: Map.get(user_counts, instance.id, 0),
           last_activity: Map.get(last_activities, instance.id),
           first_seen: Map.get(instance, :inserted_at)
         }}
      end)

    %{instances: instances, instances_metadata: instances_metadata, page_info: page_info}
  end
end
