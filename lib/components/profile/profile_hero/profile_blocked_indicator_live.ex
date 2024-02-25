defmodule Bonfire.UI.Me.ProfileBlockedIndicatorLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me.Integration

  prop user, :map
  prop is_local_user, :any, default: nil

  prop silenced_instance_wide?, :boolean, default: false
  prop ghosted_instance_wide?, :boolean, default: false
  prop ghosted?, :boolean, default: false
  prop silenced?, :boolean, default: false

  prop boundary_preset, :any, default: nil
end
