defmodule Bonfire.UI.Me.WidgetAdminsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil
  prop show_reset_btn, :boolean, default: false

  @doc "The instance admins the current viewer may see: guests only when `[WidgetAdminsLive, :show_guests]` allows it (the same guard as this widget's template)."
  def list_visible(context) do
    if current_user_id(context) ||
         Settings.get([__MODULE__, :show_guests], true, context) do
      List.wrap(Bonfire.UI.Me.WidgetUsersLive.list_admins())
    else
      []
    end
  end

  def handle_event(
        "reset",
        _,
        socket
      ) do
    Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

    {:noreply,
     socket
     #  TODO: how to update them without reloading or making this a stateful component
     |> assign_flash(
       :info,
       l("Admins have been refreshed.") <> " " <> l("You need to reload to see updates, if any.")
     )}
  end
end
