defmodule Bonfire.UI.Me.ProfileStatsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map
  prop post_count, :integer, default: 0
  prop followers_count, :integer, default: 0
  prop following_count, :integer, default: 0
end
