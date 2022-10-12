defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceMembersLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :string

  def update(assigns, socket) do
    current_user = current_user(assigns)
    tab = e(assigns, :selected_tab, nil)

    users = Bonfire.Me.Users.list(current_user)
    count = Bonfire.Me.Users.maybe_count()

    {:ok,
     assign(
       socket,
       selected_tab: tab,
       current_user: current_user,
       page_title:
          if(count,
            do: l("Users directory (%{total})", total: count),
            else: l("Users directory")
          ),
        page: "users",
        users: users
     )}
  end
end
