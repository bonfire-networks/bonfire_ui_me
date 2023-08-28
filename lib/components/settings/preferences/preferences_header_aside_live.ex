defmodule Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :atom, default: :user
  prop id, :any, default: nil
end
