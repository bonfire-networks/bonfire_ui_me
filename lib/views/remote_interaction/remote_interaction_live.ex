defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  def mount(params, session, socket) do
    # debug(session, "session")
    {:ok,
     socket
      |> assign(:canonical_url, e(params, "url", nil) || e(session, "url", nil))
      |> assign(:name, e(params, "name", nil) || e(session, "name", nil))
      |> assign(:interaction_type, e(params, "type", nil) || e(session, "type", nil) || l "follow")
    }
  end
end
