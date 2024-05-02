defmodule Bonfire.UI.Me.DeletedLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccount,
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers
            ]}

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(_params, session, socket) do
    # debug(session, "session")
    {:ok,
     socket
     |> assign(:page, l("deleted"))
     |> assign(:page_title, l("Deletion in progress"))
     #  |> assign_new(:without_sidebar, fn -> true end)
     #  |> assign_new(:without_secondary_widgets, fn -> true end)
     #  |> assign_new(:current_account, fn -> nil end)
     #  |> assign_new(:current_account_id, fn -> nil end)
     #  |> assign_new(:current_user, fn -> nil end)
     #  |> assign_new(:current_user_id, fn -> nil end)
     |> assign(:type, session["type"])}
  end
end
