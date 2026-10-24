defmodule Bonfire.UI.Me.ProfileHoverCardBodyLive do
  @moduledoc """
  What the profile hover card shows: `UserPreviewLive` with counts, "Followed by" and Follow in its `actions` slot. Its own component, rather than inline in `ProfileHoverCardLive`, because the mobile sheet passes it to `ReusableModalLive` as `modal_component`, which takes props only, not slots. See plans/profile-hover-card.md in team-docs (S1).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "What `ProfileHoverCardLive.load_card/2` returns"
  prop card, :map, required: true

  @doc "Distinct in the panel and the sheet, so the two follow buttons for the same user never share an id"
  prop parent_id, :string, required: true
end
