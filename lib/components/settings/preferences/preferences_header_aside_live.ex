defmodule Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :atom, default: nil
  prop selected_tab, :any, default: "preferences"
  prop id, :any, default: nil
end
