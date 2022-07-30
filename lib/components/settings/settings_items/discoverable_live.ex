defmodule Bonfire.UI.Me.SettingsViewsLive.DiscoverableLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop label, :string, default: nil
  prop scope, :atom, default: nil

end
