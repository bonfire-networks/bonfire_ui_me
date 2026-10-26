defmodule Bonfire.UI.Me.ProfileHoverCardLive do
  @moduledoc """
  The one profile hover card per page, mounted in the layout for logged-in viewers. It shows who someone is at once, then loads the counts, "Followed by" and "follows you" in the background. No cache, so follow state is never stale. See plans/profile-hover-card.md in team-docs.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  @doc "Who the card shows, or `nil` before the first load and after a not-found one"
  data user, :map, default: nil

  @doc "What `load_extras/2` returned for `user`, or `nil` while it loads"
  data extras, :map, default: nil

  @doc "`:panel` (desktop hover) or `:sheet` (tap); the hook opens either, the server only fills it"
  data presentation, :atom, default: :panel

  # push_event, not the event's reply: the event runs in the post's socket, so its reply would reach the hook before this card renders
  def update(
        %{load: user_or_id, requested_id: requested_id, presentation: presentation},
        socket
      ) do
    current_user = current_user(socket)

    socket =
      case load_identity(current_user, user_or_id) do
        {:ok, user} ->
          socket
          |> assign(user: user, extras: nil, presentation: presentation)
          # LiveView's own: `Utils.apply_task` can't call it (a macro) and falls back to a plain Task
          |> start_async(:card_extras, fn -> load_extras(current_user, user) end)

        {:error, :not_found} ->
          assign(socket, user: nil, extras: nil)
      end

    {:ok,
     push_event(socket, "profile_hover_card:loaded", %{
       id: requested_id,
       found: !is_nil(socket.assigns.user)
     })}
  end

  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  # LiveView drops a superseded task's result, so this always belongs to the latest load
  def handle_async(:card_extras, {:ok, extras}, socket),
    do: {:noreply, assign(socket, extras: extras)}

  def handle_async(:card_extras, _failed, socket), do: {:noreply, socket}

  # shown while the container is marked loading, so the previous person's card never shows
  defp skeleton(assigns) do
    assigns = assign_new(assigns, :sheet, fn -> false end)

    ~F"""
    <div
      data-role="profile_hover_card_skeleton"
      aria-hidden="true"
      class={"hidden flex-col gap-3 p-4", @class}
    >
      <div class="flex items-center gap-3">
        <div class="skeleton size-12 shrink-0 rounded-full" />
        <div class="flex flex-col gap-2">
          <div class="skeleton h-4 w-32" />
          <div class="skeleton h-3 w-24" />
        </div>
      </div>
      <div class="flex flex-col gap-2">
        <div class="skeleton h-3 w-full" />
        <div :if={@sheet} class="skeleton h-3 w-full" />
        <div :if={@sheet} class="skeleton h-3 w-full" />
        <div class="skeleton h-3 w-2/3" />
      </div>
      {!-- extra rows in the sheet, so its top edge jumps less when the card lands --}
      <div :if={@sheet} class="skeleton h-3 w-28" />
      <div :if={@sheet} class="skeleton h-4 w-40" />
      <div class="skeleton mt-1 h-8 w-full rounded-full" />
    </div>
    """
  end

  @doc """
  Who `user_or_id` is, as seen by `current_user`: the struct as given, or the profile page's lookup by id, so the card never shows more than the profile would. `{:error, :not_found}` without a current user or for anything that isn't a user.
  """
  def load_identity(nil, _user_or_id), do: {:error, :not_found}
  def load_identity(_current_user, %{id: _} = user), do: {:ok, user}

  def load_identity(_current_user, id) do
    # ids come from the page, so a malformed one is "not found", not a crash
    case Types.uid(id) do
      uid when is_binary(uid) -> Bonfire.Me.Users.by_id(uid)
      _ -> {:error, :not_found}
    end
  end

  @doc """
  What the card adds after it shows: whether `user` follows the viewer, the people the viewer follows who follow them, and the counts only with Vanity Metrics on (otherwise not queried).
  """
  def load_extras(current_user, user) do
    {followers_count, following_count} =
      if Bonfire.UI.Common.show_activity_counts?(nil, current_user: current_user),
        do:
          maybe_apply(Bonfire.Social.Graph.Follows, :follow_counts, [user],
            fallback_return: {nil, nil}
          ),
        else: {nil, nil}

    # for the follow button's "Follow back" / "Mutual follower" wording
    follows_me =
      maybe_apply(Bonfire.Social.Graph.Follows, :follow_status, [user, current_user],
        fallback_return: false
      ) == Bonfire.Data.Social.Follow

    {familiar_followers, familiar_followers_total} =
      maybe_apply(Bonfire.Social.Graph.Follows, :familiar_followers, [current_user, user],
        fallback_return: {[], 0}
      )

    %{
      follows_me: follows_me,
      followers_count: followers_count,
      following_count: following_count,
      familiar_followers: familiar_followers,
      familiar_followers_total: familiar_followers_total
    }
  end
end
