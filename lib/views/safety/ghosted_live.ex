defmodule Bonfire.UI.Me.GhostedLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {
      :ok,
      assign(
        socket,
        selected_tab: "ghosted",
        # without_secondary_widgets: true,
        nav_items: Bonfire.Common.ExtensionModule.default_nav(),
        back: true,
        page: "Ghosted People & Instances",
        page_title: l("Ghosted People & Instances"),
        scope: nil,
        current_params: params
      )
    }
  end
end
