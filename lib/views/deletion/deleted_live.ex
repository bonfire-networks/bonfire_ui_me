defmodule Bonfire.UI.Me.DeletedLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccount,
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers
            ]}

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page, l("deleted"))
     |> assign(:page_title, l("Deletion in progress"))
     |> assign(:type, session["type"])}
  end
end
