defmodule Bonfire.UI.Me.SwitchUserLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.AccountRequired,
              Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers
            ]}

  def mount(_, _, socket) do
    a = assigns(socket)
    active_user_id = current_user_id(socket) || a[:current_user_id]

    all_users =
      case current_account(socket) do
        %{} = account -> Bonfire.Me.Users.by_account!(account)
        _ -> a[:current_account_users] || []
      end

    active_user =
      current_user(socket) ||
        Enum.find(all_users, fn u -> id(u) == active_user_id end)

    {:ok,
     assign(
       socket,
       current_user: nil,
       current_account_users: all_users,
       active_user: active_user,
       active_user_id: id(active_user) || active_user_id,
       without_sidebar: true,
       no_header: true,
       without_secondary_widgets: true,
       go: Map.get(a, :go, ""),
       page_title: l("Switch user profile"),
       max_users_per_account:
         Config.get(
           [Bonfire.Me.Users, :max_per_account],
           4,
           :bonfire_me
         )
     )}
  end
end
