defmodule Bonfire.UI.Me.SettingsViewsLive.PreferencesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop scope, :atom, default: :user
end
