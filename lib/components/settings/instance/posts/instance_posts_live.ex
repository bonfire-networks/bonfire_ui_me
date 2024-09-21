defmodule Bonfire.UI.Me.SettingsViewsLive.InstancePostsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :any

  def update(assigns, socket) do
    current_user = current_user(assigns) || current_user(assigns(socket))
    tab = e(assigns, :selected_tab, nil)

    {:ok,
     assign(
       socket,
       selected_tab: tab,
       current_user: current_user,
       pages:
         Bonfire.Common.Utils.maybe_apply(
           Bonfire.Pages,
           :list_paginated,
           []
         )
     )}
  end
end
