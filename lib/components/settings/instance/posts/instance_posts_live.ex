defmodule Bonfire.UI.Me.SettingsViewsLive.InstancePostsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :string

  def update(assigns, socket) do
    current_user = current_user(assigns) || current_user(socket.assigns)
    tab = e(assigns, :selected_tab, nil)

    {:ok,
     assign(
       socket,
       selected_tab: tab,
       current_user: current_user,
       pages: Bonfire.Pages.list_paginated()
     )}
  end

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
