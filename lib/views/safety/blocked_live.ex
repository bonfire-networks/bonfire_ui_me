defmodule Bonfire.UI.Me.BlockedLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {
      :ok,
      assign(
        socket,
        selected_tab: "blocked",
        # without_secondary_widgets: true,
        nav_items: Bonfire.Common.ExtensionModule.default_nav(),
        back: true,
        page: "Blocked People & Instances",
        page_title: l("Blocked People & Instances"),
        scope: nil,
        current_params: params
      )
    }
  end
end
