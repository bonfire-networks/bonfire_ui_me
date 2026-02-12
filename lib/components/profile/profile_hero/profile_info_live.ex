defmodule Bonfire.UI.Me.ProfileInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me

  prop user, :map

  prop path, :string, default: "@"
  prop selected_tab, :any, default: nil
  prop character_type, :atom, default: nil
  prop is_local?, :boolean, default: false
  prop post_count, :any, default: nil
  prop followers_count, :any, default: nil
  prop following_count, :any, default: nil

  # prop follows_me, :atom, default: false
  prop aliases, :any, default: []
  prop familiar_followers, :list, default: []

  slot header
end
