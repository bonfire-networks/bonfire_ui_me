defmodule Bonfire.UI.Me.WidgetUserStatusLive do
  @moduledoc "Dashboard widget showing a narrative overview of the user's account: activity, connections, federation, and safety setup."
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget("User Status")

  # 2 minutes
  @cache_ttl 1_000 * 60 * 2

  @doc "Gathers user-level data, cached per user for 2 minutes."
  def load(current_user) do
    if user_id = Types.uid(current_user) do
      Cache.maybe_apply_cached(
        {__MODULE__, :do_load},
        [current_user],
        expire: @cache_ttl,
        cache_key: "widget_user_status:#{user_id}"
      )
    end
  end

  def do_load(current_user) do
    user_id = Types.uid(current_user)
    opts = [current_user: current_user, skip_boundary_check: true]
    username = e(current_user, :character, :username, nil)

    join_date = Bonfire.Common.DatesTimes.date_from_pointer(current_user)

    join_date_formatted =
      case join_date do
        %DateTime{} = dt -> Bonfire.Common.DatesTimes.format_date(dt)
        _ -> nil
      end

    post_count =
      if module_enabled?(Bonfire.Posts) do
        try do
          Bonfire.Posts.count_for_user(current_user) || 0
        rescue
          _ -> 0
        end
      else
        0
      end

    bookmark_count =
      try do
        Bonfire.Social.Bookmarks.count(subjects: user_id) || 0
      rescue
        _ -> 0
      end

    followers_count =
      try do
        Bonfire.Social.Edges.count(Bonfire.Social.Graph.Follows, [objects: user_id],
          skip_boundary_check: true
        ) || 0
      rescue
        _ -> 0
      end

    following_count =
      try do
        Bonfire.Social.Edges.count(Bonfire.Social.Graph.Follows, [subjects: user_id],
          skip_boundary_check: true
        ) || 0
      rescue
        _ -> 0
      end

    user_federating? =
      if module_enabled?(Bonfire.Federate.ActivityPub) do
        Bonfire.Federate.ActivityPub.federating?(current_user)
      end

    # :block returns both silence and ghost circles — blocked = intersection of both
    {blocked_count, ghosted_count, silenced_count} =
      try do
        circles = Bonfire.Boundaries.Blocks.list(:block, opts)

        {silence_ids, ghost_ids} =
          case circles do
            [silence_circle, ghost_circle] ->
              s =
                e(silence_circle, :encircles, [])
                |> Enum.map(&e(&1, :subject_id, nil))
                |> Enum.reject(&is_nil/1)
                |> MapSet.new()

              g =
                e(ghost_circle, :encircles, [])
                |> Enum.map(&e(&1, :subject_id, nil))
                |> Enum.reject(&is_nil/1)
                |> MapSet.new()

              {s, g}

            _ ->
              {MapSet.new(), MapSet.new()}
          end

        {
          MapSet.intersection(silence_ids, ghost_ids) |> MapSet.size(),
          MapSet.size(ghost_ids),
          MapSet.size(silence_ids)
        }
      rescue
        _ -> {0, 0, 0}
      end

    dm_privacy =
      Bonfire.Common.Settings.get(
        [Bonfire.Messages, :dm_privacy],
        "everyone",
        current_user: current_user
      )
      |> to_string()

    undiscoverable? =
      Bonfire.Common.Settings.get(
        [Bonfire.Me.Users, :undiscoverable],
        false,
        current_user: current_user
      ) == true

    search_indexing_disabled? =
      Bonfire.Common.Settings.get(
        [Bonfire.Search.Indexer, :modularity],
        nil,
        current_user: current_user
      ) == :disabled

    %{
      user_name: e(current_user, :profile, :name, nil) || username || "",
      username: username,
      join_date_formatted: join_date_formatted,
      post_count: post_count,
      bookmark_count: bookmark_count,
      followers_count: followers_count,
      following_count: following_count,
      user_federating?: user_federating?,
      blocked_count: blocked_count,
      ghosted_count: ghosted_count,
      silenced_count: silenced_count,
      dm_privacy: dm_privacy,
      undiscoverable?: undiscoverable?,
      search_indexing_disabled?: search_indexing_disabled?
    }
  end
end
