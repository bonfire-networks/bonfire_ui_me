defmodule Bonfire.UI.Me.UsersGridLive do
  @moduledoc """
  A grid of people, for widgets in a main area (eg. the moderators, or a circle's members):

  - `:links` (default): a card per person with their avatar, name and handle, linking to their profile
  - `:portrait`: avatar tiles (`Bonfire.UI.Me.UserPreviewLive`'s portrait variant)
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop users, :list, default: []
  prop variant, :atom, default: :links, values: [:links, :portrait]

  @doc "Prefix of each person's link id (`<parent_id>-<user id>`) and of the avatars' ids, so two grids on a page don't clash."
  prop parent_id, :string, required: true

  @doc "The `data-role` of each person's link."
  prop item_role, :string, default: "user-link"

  @doc "Where profile links open, eg. `_blank` in an embed."
  prop target, :string, default: nil

  @doc "Shown under the grid, such as a button that acts on all the people at once."
  slot footer
end
