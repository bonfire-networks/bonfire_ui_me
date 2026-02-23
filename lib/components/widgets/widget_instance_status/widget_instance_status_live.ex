defmodule Bonfire.UI.Me.WidgetInstanceStatusLive do
  @moduledoc "Dashboard widget showing a narrative overview of the instance: name, version, community size, federation, and admin contacts."
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget("Instance Status")

  # 60 seconds
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
          Bonfire.Boundaries.Blocks.list(nil, :instance_wide)
          |> Enum.flat_map(fn circle ->
            e(circle, :encircles, [])
            |> Enum.filter(&e(&1, :peer, nil))
          end)
          |> length()
        rescue
          _ -> 0
        end
      else
        0
      end

    admins =
      try do
        Bonfire.UI.Me.WidgetUsersLive.list_admins()
      rescue
        _ -> []
      end

    known_instances_count =
      if federation_enabled? do
        try do
          Bonfire.Federate.ActivityPub.Instances.list() |> length()
        rescue
          _ -> 0
        end
      else
        0
      end

    %{
      instance_name: Bonfire.Application.name(),
      instance_image: Bonfire.Common.Settings.get([:ui, :theme, :instance_image], nil),
      user_count: Bonfire.Me.Users.count(:local) || 0,
      online_count: Bonfire.UI.Common.Presence.list() |> map_size(),
      invite_only?: Bonfire.Me.Accounts.instance_is_invite_only?(),
      federation_enabled?: federation_enabled?,
      blocked_instances_count: blocked_instances_count,
      known_instances_count: known_instances_count,
      admins: admins || [],
      instance_description: Bonfire.Common.Settings.get([:ui, :theme, :instance_description], nil)
    }
  end
end
