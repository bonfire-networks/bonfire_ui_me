defmodule Bonfire.UI.Me.WidgetInstanceStatusLive do
  @moduledoc "Dashboard widget showing a narrative overview of the instance: name, version, community size, federation, and admin contacts."
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget("Instance Status")

  # 60 seconds # TODO: cache some things longer (e.g. instance name and image, which are unlikely to change often, along with user_count and blocked) and some things shorter (e.g. online count, or settings if they can be changed from the UI and we want changes to be reflected semi-immediately)
  @cache_ttl 1_000 * 60

  @doc "Gathers instance-level data, cached for 60 seconds since it's shared across all users."
  def load do
    Cache.maybe_apply_cached(&do_load/0, [], expire: @cache_ttl)
  end

  defp do_load do
    federation_enabled? =
      module_enabled?(Bonfire.Federate.ActivityPub) and
        Bonfire.Federate.ActivityPub.federating?()

    blocked_instances_count =
      if federation_enabled? do
        try do
          Bonfire.Boundaries.Blocks.count_blocked(:instance_wide)
        rescue
          _ -> 0
        end
      end

    admins =
      try do
        # no need to cache count because the list is cached
        Bonfire.UI.Me.WidgetUsersLive.list_admins()
      rescue
        _ -> []
      end

    known_instances_count =
      if federation_enabled? do
        try do
          Bonfire.Federate.ActivityPub.Instances.count()
        rescue
          _ -> 0
        end
      end

    incoming_instances_count =
      if federation_enabled? do
        try do
          Bonfire.Federate.ActivityPub.Instances.count_instances_following_local()
        rescue
          _ -> 0
        end
      end

    outgoing_instances_count =
      if federation_enabled? do
        try do
          Bonfire.Federate.ActivityPub.Instances.count_instances_followed_by_local()
        rescue
          _ -> 0
        end
      end

    incoming_instances_count = incoming_instances_count || 0
    outgoing_instances_count = outgoing_instances_count || 0
    blocked_instances_count = blocked_instances_count || 0

    federation_details =
      [
        if(outgoing_instances_count > 0,
          do: l("we follow %{count}", count: outgoing_instances_count)
        ),
        if(incoming_instances_count > 0,
          do: l("%{count} follow us", count: incoming_instances_count)
        ),
        if(blocked_instances_count > 0, do: l("%{count} blocked", count: blocked_instances_count))
      ]
      |> Enum.reject(&is_nil/1)
      |> join_with_and()

    %{
      instance_name: Bonfire.Application.name(),
      instance_image: Bonfire.Common.Settings.get([:ui, :theme, :instance_image], nil),
      user_count: Bonfire.Me.Users.count(:local) || 0,
      online_count: Bonfire.UI.Common.Presence.count() || 0,
      invite_only?: Bonfire.Me.Accounts.instance_is_invite_only?(),
      federation_enabled?: federation_enabled?,
      known_instances_count: known_instances_count || 0,
      federation_details: federation_details,
      admins: admins || [],
      instance_description: Bonfire.Common.Settings.get([:ui, :theme, :instance_description], nil)
    }
  end

  defp join_with_and([]), do: nil
  defp join_with_and([single]), do: single
  defp join_with_and([a, b]), do: l("%{first} and %{second}", first: a, second: b)

  defp join_with_and(parts) do
    {last, rest} = List.pop_at(parts, -1)
    Enum.join(rest, ", ") <> ", " <> l("and %{last}", last: last)
  end
end
