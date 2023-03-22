defmodule Bonfire.UI.Me.SwitchUserLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.AccountRequired,
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers
            ]}

  def mount(_, _, socket),
    do:
      {:ok,
       assign(
         socket,
         current_user: nil,
         without_sidebar: true,
         without_widgets: true,
         go: Map.get(socket.assigns, :go, ""),
         page_title: l("Switch user profile")
       )}
end
