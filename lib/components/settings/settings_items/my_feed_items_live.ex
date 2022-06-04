defmodule Bonfire.UI.Me.SettingsViewsLive.MyFeedItemsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string
  prop scope, :atom, default: nil

end
