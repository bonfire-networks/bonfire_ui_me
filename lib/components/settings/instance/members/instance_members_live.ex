defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceMembersLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :string
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil

  def preload([%{skip_preload: true}] = list_of_assigns) do
    list_of_assigns
  end

  def preload(list_of_assigns) do
    Bonfire.Social.Block.LiveHandler.preload(list_of_assigns, caller_module: __MODULE__)
  end

  def update(assigns, socket) do
    IO.inspect(assigns, label: "assigns")
    current_user = current_user(assigns)
    tab = e(assigns, :selected_tab, nil)

    users = Bonfire.Me.Users.list(current_user)
    count = Bonfire.Me.Users.maybe_count()

    {:ok,
     assign(
       socket,
       selected_tab: tab,
       ghosted_instance_wide?: nil,
       silenced_instance_wide?: nil,
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
