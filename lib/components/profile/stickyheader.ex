defmodule Bonfire.UI.Me.Stickyheader do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me

  prop user, :map
  prop character_type, :atom, default: nil
  prop boundary_preset, :any, default: nil
  prop aliases, :any, default: nil
  prop skip_preload, :boolean, default: false
  prop ghosted?, :boolean, default: nil
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil
  prop members, :any, default: nil
  prop moderators, :any, default: nil
  prop permalink, :string, default: nil
end
