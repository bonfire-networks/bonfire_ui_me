defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop uploads, :any
end
