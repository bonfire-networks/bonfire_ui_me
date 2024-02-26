defmodule Bonfire.UI.Me.InstancesDirectoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Bonfire.UI.Me.Integration

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    current_user = current_user(socket.assigns)

    show_to =
      Bonfire.Common.Settings.get(
        [Bonfire.UI.Me.UsersDirectoryLive, :show_to],
        :users
      )

    if show_to ||
         maybe_apply(Bonfire.Me.Accounts, :is_admin?, socket.assigns[:__context__]) == true do
      if show_to == :guests or current_user(socket.assigns) || current_account(socket) do
        instances = Bonfire.Federate.ActivityPub.Instances.list()

        # Bonfire.Me.Users.maybe_count()
        count = length(instances)

        is_guest? = is_nil(current_user)

        {:ok,
         assign(
           socket,
           page_title:
             if(count,
               do: l("Known fediverse instances (%{total})", total: count),
               else: l("Known fediverse instances")
             ),
           page: "known_instances",
           selected_tab: :instances,
           is_guest?: is_guest?,
           without_sidebar: is_guest?,
           without_secondary_widgets: is_guest?,
           no_header: is_guest?,
           nav_items: Bonfire.Common.ExtensionModule.default_nav(),
           instances: instances
         )}
      else
        throw(l("You need to log in before browsing the user directory"))
      end
    else
      throw(l("The user directory is disabled on this instance"))
    end
  end
end
