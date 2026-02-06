defmodule Bonfire.UI.Me.SilencedLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {
      :ok,
      assign(
        socket,
        selected_tab: "silenced",
        # without_secondary_widgets: true,

        back: true,
        page: "Silenced People & Instances",
        page_title: l("Silenced People & Instances"),
        scope: nil,
        current_params: params
      )
    }
  end
end
