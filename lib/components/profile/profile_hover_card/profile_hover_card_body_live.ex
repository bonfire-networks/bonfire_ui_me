defmodule Bonfire.UI.Me.ProfileHoverCardBodyLive do
  @moduledoc """
  What the profile hover card shows: `UserPreviewLive` with counts, "Followed by" and Follow in its `actions` slot. Rendered in the desktop panel and the bottom sheet.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Who to show, from `ProfileHoverCardLive.load_identity/2`"
  prop user, :map, required: true

  @doc "What `ProfileHoverCardLive.load_extras/2` returned, or `nil` while it loads"
  prop extras, :any, default: nil

  @doc "In the bottom sheet: bio unclamped, no inner border, Follow sticky at the bottom"
  prop sheet, :boolean, default: false

  @doc "Distinct in the panel and the sheet, so the two follow buttons for the same user never share an id"
  prop parent_id, :string, required: true
end
