defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive do
  @moduledoc """
  Read-only summary of the instance's defaults, shown both in instance settings and on the
  public `/about` page (so guests can see how this community is configured).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Reads community defaults without applying the visiting member's personal preferences."
  def community_defaults do
    %{
      boundaries: Bonfire.Boundaries.Presets.default_boundaries(scope: :instance),
      directory: Config.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to], :users),
      post_length: Bonfire.UI.Common.SmartInput.LiveHandler.max_length(),
      federation: federation_mode(),
      undiscoverable: Settings.get([Bonfire.Me.Users, :undiscoverable], false, scope: :instance),
      indexable: Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, scope: :instance),
      forward_reports:
        Settings.get([Bonfire.Social.Flags, :forward_by_default], false, scope: :instance),
      blur_media:
        Settings.get([Bonfire.UI.Social.Activity.MediaLive, :hide], false, scope: :instance),
      language:
        Config.get([Bonfire.Common.Localise.Cldr, :default_locale], "en")
        |> Bonfire.Common.Localise.locale_name(),
      scrolling: Settings.get([:ui, :infinite_scroll], :preload, scope: :instance),
      counts: Settings.get([:ui, :show_activity_counts], false, scope: :instance)
    }
  end

  @doc "Lists the starting home-feed preferences, using the same keys as the preference controls."
  def feed_defaults do
    [
      {:followed_categories, l("Activities from groups I follow")},
      {:boost, l("Boosts")},
      {:reply, l("Replies")},
      {:follow, l("Follows")},
      {:outbox, l("User's own activities")},
      {:notifications, l("Notifications")}
    ]
    |> Enum.map(fn {key, label} ->
      {key, label, Settings.get([Bonfire.Social.Feeds, :include, key], true, scope: :instance)}
    end)
  end

  # how many allowlisted entries to show before summarising the rest as "+N more"
  @allowlist_preview_limit 50

  @doc """
  The instance's effective federation mode, from the canonical `Bonfire.Federate.ActivityPub.federation_mode/0`, the same source the footer
  (`ImpressumLive`) and the mode selector use, so all three agree.
  """
  def federation_mode do
    maybe_apply(Bonfire.Federate.ActivityPub, :federation_mode, [], fallback_return: false)
  end

  @doc """
  The instance-wide federation allowlist as `{members_to_show, total_count}`. Only meaningful
  in `:allowlist_only` mode, where these are the only instances and people we federate with.
  """
  def instance_allowlist do
    members =
      Bonfire.Boundaries.Allowlist.list_members(:instance_wide, paginate: false)
      |> List.wrap()

    {Enum.take(members, @allowlist_preview_limit), length(members)}
  end

  @doc """
  Display info for an allowlist entry, which can be a person or a whole instance: an `icon`,
  a `label`, the `url` to link to, and `favicon_for` (the site to show a favicon of, when the
  entry is an instance). Only reads what `Circles.list_members/2` already preloads, to avoid a
  query per entry.
  """
  def allowlist_entry(member) do
    subject = e(member, :subject, nil)

    cond do
      name = e(subject, :profile, :name, nil) ->
        %{icon: "ph:user-duotone", label: name, url: actor_url(subject), favicon_for: nil}

      username = e(subject, :character, :username, nil) ->
        %{icon: "ph:user-duotone", label: username, url: actor_url(subject), favicon_for: nil}

      host = e(subject, :named, :name, nil) ->
        # an instance entry is a circle named after the hostname, see `Instances.get_or_create_instance_circle/1`
        url = "https://#{host}"
        %{icon: "ph:globe-duotone", label: host, url: url, favicon_for: url}

      true ->
        %{icon: "ph:question-duotone", label: l("Unknown"), url: nil, favicon_for: nil}
    end
  end

  defp actor_url(subject) do
    e(subject, :character, :peered, :canonical_uri, nil) ||
      case e(subject, :character, :username, nil) do
        nil -> nil
        username -> "/@#{username}"
      end
  end
end
