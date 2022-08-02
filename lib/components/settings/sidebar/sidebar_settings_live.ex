
defmodule  Bonfire.UI.Me.SettingsViewLive.SidebarSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop id, :string, default: nil

end
