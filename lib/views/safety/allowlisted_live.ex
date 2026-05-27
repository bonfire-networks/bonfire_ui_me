defmodule Bonfire.UI.Me.AllowlistedLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {
      :ok,
      assign(
        socket,
        selected_tab: "allowlisted",
        back: true,
        page: "allowlisted",
        page_title: l("Federation Archipelago"),
        scope: nil,
        current_params: params
      )
    }
  end
end
