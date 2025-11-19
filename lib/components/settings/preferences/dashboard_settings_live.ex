defmodule Bonfire.UI.Me.SettingsViewsLive.DashboardSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :any
  prop scope, :atom, default: nil
end
