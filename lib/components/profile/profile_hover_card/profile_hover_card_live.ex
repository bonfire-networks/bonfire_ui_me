defmodule Bonfire.UI.Me.ProfileHoverCardLive do
  @moduledoc """
  The one profile hover card per page, mounted in the layout for logged-in viewers. Its hook asks for a user with the `load` event; this component looks them up and renders `Bonfire.UI.Me.ProfileHoverCardBodyLive`. Nothing is cached, so follow state is never stale. See plans/profile-hover-card.md in team-docs.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  @doc "What the card shows, or `nil` before the first load and after a not-found one"
  data card, :map, default: nil

  # the reply carries the id so the hook can drop a reply for a link it has moved away from
  def handle_event("load", %{"id" => id}, socket) do
    case load_card(current_user(socket), id) do
      {:ok, card} -> {:reply, %{id: id, found: true}, assign(socket, card: card)}
      {:error, :not_found} -> {:reply, %{id: id, found: false}, assign(socket, card: nil)}
    end
  end

  @doc """
  Gathers what the card shows for user `id`, as seen by `current_user`: the user, whether they follow the viewer (the follow button loads the viewer's side itself), the people the viewer follows who follow them (`Follows.familiar_followers/3`), and the counts only when the viewer turned on Vanity Metrics (otherwise they aren't loaded at all).

  Uses the same unchecked lookup as the profile page, so the card never shows more than clicking through would. Returns `{:error, :not_found}` without a current user, or when `id` isn't a user (a group, a post, a deleted user).
  """
  def load_card(nil, _id), do: {:error, :not_found}

  def load_card(current_user, id) do
    # the id comes from the page, so anything that isn't one is "not found", not a cast error crashing the LiveView
    with uid when is_binary(uid) <- Types.uid(id),
         {:ok, user} <- Bonfire.Me.Users.by_id(uid) do
      # only queried when counts show; accepted follows only, the same numbers as the profile page
      {followers_count, following_count} =
        if Bonfire.UI.Common.show_activity_counts?(nil, current_user: current_user),
          do:
            maybe_apply(Bonfire.Social.Graph.Follows, :follow_counts, [user],
              fallback_return: {nil, nil}
            ),
          else: {nil, nil}

      # the follow button loads the viewer's own follow state and permission itself; this only adds "do they follow me", for its "Follow back" / "Mutual follower" wording
      follows_me =
        maybe_apply(Bonfire.Social.Graph.Follows, :follow_status, [user, current_user],
          fallback_return: false
        ) == Bonfire.Data.Social.Follow

      {familiar_followers, familiar_followers_total} =
        maybe_apply(
          Bonfire.Social.Graph.Follows,
          :familiar_followers,
          [current_user, user],
          fallback_return: {[], 0}
        )

      {:ok,
       %{
         user: user,
         familiar_followers: familiar_followers,
         familiar_followers_total: familiar_followers_total,
         follows_me: follows_me,
         followers_count: followers_count,
         following_count: following_count
       }}
    else
      _ -> {:error, :not_found}
    end
  end
end
