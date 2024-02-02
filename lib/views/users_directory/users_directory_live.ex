defmodule Bonfire.UI.Me.UsersDirectoryLive do
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
        users = Bonfire.Me.Users.list(current_user)

        count = Bonfire.Me.Users.maybe_count()

        {:ok,
         assign(
           socket,
           page_title:
             if(count,
               do: l("Users directory (%{total})", total: count),
               else: l("Users directory")
             ),
           page: "users",
           selected_tab: :users,
           is_guest?: is_nil(current_user_id(socket.assigns)),
           without_sidebar: is_nil(current_user_id(socket.assigns)),
           without_secondary_widgets: is_nil(current_user_id(socket.assigns)),
           no_header: is_nil(current_user_id(socket.assigns)),
           nav_items: Bonfire.Common.ExtensionModule.default_nav(),
           search_placeholder: "Search users",
           users: users
         )}
      else
        throw(l("You need to log in before browsing the user directory"))
      end
    else
      throw(l("The user directory is disabled on this instance"))
    end
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
