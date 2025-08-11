defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # debug(session, "session")
    page =
      Text.text_only(
        e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction")
      )

    {:ok,
     socket
     |> assign_new(:without_sidebar, fn -> true end)
     |> assign_new(:no_header, fn -> true end)
     |> assign_new(:without_secondary_widgets, fn -> true end)
     |> assign(:canonical_url, Text.text_only(e(params, "url", nil) || e(session, "url", nil)))
     |> assign(:name, Text.text_only(e(params, "name", nil) || e(session, "name", nil)))
     |> assign(
       :page,
       page
     )
     |> assign(
       :page_title,
       page
     )
     |> assign(
       :interaction_type,
       Text.text_only(e(params, "type", nil) || e(session, "type", nil)) || l("follow")
     )}
  end
end
