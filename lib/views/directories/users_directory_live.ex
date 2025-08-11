defmodule Bonfire.UI.Me.UsersDirectoryLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # import Bonfire.UI.Me

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    current_user = current_user(socket)

    show_to =
      Bonfire.Common.Settings.get(
        [Bonfire.UI.Me.UsersDirectoryLive, :show_to],
        :users
      )

    if show_to ||
         maybe_apply(Bonfire.Me.Accounts, :is_admin?, [assigns(socket)[:__context__]],
           fallback_return: nil
         ) == true do
      if (show_to == :guests or current_user) || current_account(socket) do
        instance =
          if instance = params["instance"] do
            case uid(instance) do
              nil ->
                Bonfire.Federate.ActivityPub.Instances.get_by_domain(instance)

              instance_id ->
                ok_unwrap(Bonfire.Federate.ActivityPub.Instances.get_by_id(instance_id))
            end
          end
          |> debug("instanceeee")

        instance_id = id(instance)

        {title, %{page_info: page_info, edges: edges}} =
          list_users(current_user, params, instance)

        is_guest? = is_nil(current_user)

        {:ok,
         assign(
           socket,
           page_title: title,
           page: "users",
           instance: instance,
           back: true,
           instance_id: instance_id,
           is_remote?: not is_nil(instance_id),
           selected_tab: :users,
           is_guest?: is_guest?,
           nav_items: Bonfire.Common.ExtensionModule.default_nav(),
           search_placeholder: "Search users",
           users: edges,
           page_info: page_info
         )}
      else
        throw(l("You need to log in before browsing the user directory"))
      end
    else
      throw(l("The user directory is disabled on this instance"))
    end
  end

  def handle_event("load_more", attrs, socket) do
    {_title, %{page_info: page_info, edges: edges}} =
      list_users(current_user(socket), attrs, e(assigns(socket), :instance_id, nil))

    {:noreply,
     socket
     |> assign(
       loaded: true,
       users: e(assigns(socket), :users, []) ++ edges,
       page_info: page_info
     )}
  end

  def list_users(current_user, params, instance \\ nil) do
    paginate =
      input_to_atoms(params)
      |> debug

    if instance do
      {l("Instance directory: ") <> "#{e(instance, :display_hostname, nil)}",
       Bonfire.Me.Users.list_paginated(
         show: {:instance, id(instance)},
         current_user: current_user,
         paginate: paginate
       )}
    else
      count = Bonfire.Me.Users.maybe_count()

      title =
        if(count,
          do: l("Users directory (%{total})", total: count),
          else: l("Users directory")
        )

      {title,
       Bonfire.Me.Users.list_paginated(
         current_user: current_user,
         paginate: paginate
       )}
    end
    |> debug("listed users")
  end
end
