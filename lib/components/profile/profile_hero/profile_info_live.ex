defmodule Bonfire.UI.Me.ProfileInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me

  prop user, :map

  prop path, :string, default: "@"
  prop selected_tab, :any, default: nil
  prop character_type, :atom, default: nil
  prop is_local?, :boolean, default: false

  # prop follows_me, :atom, default: false
  prop aliases, :any, default: []

  slot header
end
