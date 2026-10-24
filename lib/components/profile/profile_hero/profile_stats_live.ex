defmodule Bonfire.UI.Me.ProfileStatsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map
  prop post_count, :any, default: nil
  prop followers_count, :any, default: nil
  prop following_count, :any, default: nil
  prop character_type, :atom, default: nil

  @doc "Smaller numbers and tighter spacing, for the profile hover card"
  prop compact, :boolean, default: false
end
