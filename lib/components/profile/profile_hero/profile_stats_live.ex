defmodule Bonfire.UI.Me.ProfileStatsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map
  prop post_count, :any, default: nil
  prop followers_count, :any, default: nil
  prop following_count, :any, default: nil
end
