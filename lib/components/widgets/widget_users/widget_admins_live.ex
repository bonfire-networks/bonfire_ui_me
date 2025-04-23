defmodule Bonfire.UI.Me.WidgetAdminsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil
  prop show_reset_btn, :boolean, default: true

  def handle_event(
        "reset",
        _,
        socket
      ) do
    Bonfire.UI.Me.WidgetUsersLive.list_admins_reset()

    debug("")

    {:noreply,
     socket
     #  TODO: how to update them without reloading or making this a stateful component
     |> assign_flash(
       :info,
       l("Admins have been refreshed.") <> l(" You need to reload to see updates, if any.")
     )}
  end
end
