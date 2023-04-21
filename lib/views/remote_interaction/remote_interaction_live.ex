defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # debug(session, "session")
    {:ok,
     socket
     |> assign(:canonical_url, e(params, "url", nil) || e(session, "url", nil))
     |> assign(:name, e(params, "name", nil) || e(session, "name", nil))
     |> assign(:page, e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction"))
     |> assign(:page_title, e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction"))
     |> assign(
       :interaction_type,
       e(params, "type", nil) || e(session, "type", nil) || l("follow")
     )}
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
