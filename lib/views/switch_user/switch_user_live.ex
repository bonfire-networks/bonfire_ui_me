defmodule Bonfire.UI.Me.SwitchUserLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.AccountRequired,
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers
            ]}

  def mount(_, _, socket),
    do:
      {:ok,
       assign(
         socket,
         current_user: nil,
         without_sidebar: true,
         no_header: true,
         without_secondary_widgets: true,
         go: Map.get(assigns(socket), :go, ""),
         page_title: l("Switch user profile"),
         max_users_per_account:
           Config.get(
             [Bonfire.Me.Users, :max_per_account],
             4,
             :bonfire_me
           )
       )}
end
