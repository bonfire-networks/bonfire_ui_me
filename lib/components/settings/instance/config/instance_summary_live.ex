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
      indexable: indexable?(),
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

  # how many allowlisted entries to show before summarising the rest as "+N more"
  @allowlist_preview_limit 50

  @doc """
  The instance's effective federation mode, from the canonical `Bonfire.Federate.ActivityPub.federation_mode/0`, the same source the footer
  (`ImpressumLive`) and the mode selector use, so all three agree.
  """
  def federation_mode do
    maybe_apply(Bonfire.Federate.ActivityPub, :federation_mode, [], fallback_return: false)
  end

  @doc "Whether content is indexed for search by default."
  def indexable?,
    do: Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, scope: :instance)

  @doc """
  Federation and search visibility, for the About page's meta line.

      iex> Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive.meta_facts(true, false)
      ["Connected to the fediverse", "Hidden from search engines"]

      iex> Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive.meta_facts(false, true)
      ["Not connected to the fediverse", "Visible in search"]
  """
  def meta_facts(federation, indexable?) do
    [
      case federation do
        true -> l("Connected to the fediverse")
        :allowlist_only -> l("Connected to selected communities")
        nil -> l("Connects to the fediverse on request")
        _ -> l("Not connected to the fediverse")
      end,
      if(indexable?, do: l("Visible in search"), else: l("Hidden from search engines"))
    ]
  end

  @doc """
  The names of the default boundaries, or `nil` when none is set.

      iex> Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive.audience_name([{"1", "Public"}, {"2", "Local"}])
      "Public, Local"

      iex> Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive.audience_name(nil)
      nil
  """
  def audience_name(boundaries) when is_list(boundaries) and boundaries != [],
    do: Enum.map_join(boundaries, ", ", fn {_id, name} -> name end)

  def audience_name({_id, name}), do: name
  def audience_name(_), do: nil

  @doc """
  Community defaults as `%{id, label, value}` rows, worded as a visitor would ask rather than as the settings are. `value` is `:allowlist` for allowlist-only federation.
  """
  def setting_rows(defaults) do
    [
      %{
        id: "community-post-audience",
        label: l("Default audience"),
        value: audience_name(defaults.boundaries) || "—"
      },
      %{
        id: "community-federation",
        label: l("Connects to"),
        value:
          case defaults.federation do
            true -> l("The whole fediverse")
            :allowlist_only -> :allowlist
            nil -> l("Only on request")
            _ -> l("Nobody, federation is off")
          end
      },
      %{
        id: "community-discoverability",
        label: l("Profiles in search"),
        value: if(defaults.undiscoverable, do: l("Hidden"), else: l("Visible"))
      },
      %{
        id: "community-indexing",
        label: l("Posts in search"),
        value: if(defaults.indexable, do: l("Visible"), else: l("Hidden"))
      },
      %{
        id: "community-directory",
        label: l("Member list"),
        value:
          case defaults.directory do
            :guests -> l("Anyone")
            :admins -> l("Admins only")
            _ -> l("Members only")
          end
      },
      (is_integer(defaults.post_length) and defaults.post_length > 0) &&
        %{
          id: "community-post-length",
          label: l("Post length"),
          value: l("Up to %{count} words", count: defaults.post_length)
        },
      %{
        id: "community-scrolling",
        label: l("Feeds"),
        value:
          if(defaults.scrolling == true,
            do: l("Load as you scroll"),
            else: l("\"Show more\" button")
          )
      },
      %{
        id: "community-reaction-counts",
        label: l("Like and follower counts"),
        value: if(defaults.counts, do: l("Shown"), else: l("Hidden"))
      },
      %{
        id: "community-media",
        label: l("Media"),
        value: if(defaults.blur_media, do: l("Blurred"), else: l("Not blurred"))
      },
      %{id: "community-interface-language", label: l("Language"), value: defaults.language},
      %{
        id: "community-report-forwarding",
        label: l("Reports on remote posts"),
        value:
          if(defaults.forward_reports,
            do: l("Also sent to their server"),
            else: l("Stay with our moderators")
          )
      }
    ]
    |> Enum.filter(& &1)
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
