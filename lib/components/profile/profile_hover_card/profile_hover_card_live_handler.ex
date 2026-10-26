defmodule Bonfire.UI.Me.ProfileHoverCardLive.LiveHandler do
  @moduledoc """
  Routes the card's `load`. It arrives through the component the hovered link sits in, so from a post's `ActivityLive` the card reuses the user that post loaded; anywhere else it loads by id.
  """
  use Bonfire.UI.Common.Web, :live_handler

  def handle_event("load", %{"id" => id} = params, socket) do
    maybe_send_update(Bonfire.UI.Me.ProfileHoverCardLive, "profile_hover_card",
      load: post_user(assigns(socket), id) || id,
      requested_id: id,
      presentation: if(params["sheet"] == true, do: :sheet, else: :panel)
    )

    {:noreply, socket}
  end

  # by its `activity` assign: `live_handler_via_module` never reaches delegated handlers (plans/profile-hover-card.md, phase 2, blocker 1)
  defp post_user(%{activity: _} = assigns, id) do
    maybe_apply(Bonfire.UI.Social.ActivityLive, :hovercard_user, [assigns, id],
      fallback_return: nil
    )
  end

  defp post_user(_assigns, _id), do: nil
end
