defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceExportLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :any
  prop scope, :atom, default: :instance_wide
end
