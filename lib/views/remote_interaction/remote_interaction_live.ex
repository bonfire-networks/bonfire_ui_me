defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      # LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ]
  end

  def mounted(params, session, socket) do
    # debug(session, "session")
    {:ok,
     socket
      |> assign(:canonical_url, e(params, "url", nil) || e(session, "url", nil))
      |> assign(:name, e(params, "name", nil) || e(session, "name", nil))
      |> assign(:interaction_type, e(params, "type", nil) || e(session, "type", nil) || l "follow")
    }
  end
end
