defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # debug(session, "session")
    {:ok,
     socket
     |> assign_new(:without_sidebar, fn -> true end)
     |> assign_new(:without_secondary_widgets, fn -> true end)
     |> assign(:canonical_url, e(params, "url", nil) || e(session, "url", nil))
     |> assign(:name, e(params, "name", nil) || e(session, "name", nil))
     |> assign(
       :page,
       e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction")
     )
     |> assign(
       :page_title,
       e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction")
     )
     |> assign(
       :interaction_type,
       e(params, "type", nil) || e(session, "type", nil) || l("follow")
     )}
  end
end
