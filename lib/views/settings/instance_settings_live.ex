defmodule Bonfire.UI.Me.InstanceSettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  # import Untangle

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Instance Settings"),
       #  without_secondary_widgets: true,
       nav_items: Bonfire.UI.Me.InstanceSidebarSettingsNavLive.declared_nav() |> List.wrap(),
       without_sidebar: :minimal,
       back: true,
       selected_tab: "instance_dashboard",
       id: nil,
       section: nil,
       page: "instance_settings",
       trigger_submit: false,
       scope: :instance
     )
     # the members' Dashboard tab shows its own sidebar list, so the layout's sidebar is hidden there and back on for any other tab, the Homepage tab included
     |> Phoenix.LiveView.attach_hook(:dashboard_tab_layout, :handle_params, fn params,
                                                                               _url,
                                                                               socket ->
       {:cont,
        assign(socket,
          without_secondary_widgets: params["tab"] == "dashboard" and params["place"] != "home"
        )}
     end)}
  end

  # Unwrap /settings/instance/boundaries/:sub_tab which otherwise matches
  # /settings/instance/:tab/:id as {tab: "boundaries", id: sub_tab}.
  def handle_params(%{"tab" => "boundaries", "id" => sub_tab} = params, url, socket) do
    handle_params(
      params
      |> Map.put("tab", sub_tab)
      |> Map.put("id", params["section"])
      |> Map.delete("section"),
      url,
      socket
    )
  end

  # No scope switcher on the instance-wide blocks pages: there's no per-user or
  # per-account equivalent (account-level blocks don't exist, and /settings/user/blocked
  # has no settings page → "No settings available"), so showing the persona toggle was
  # broken. See bonfire-app#2018. `page_header_aside: nil` also clears any stale aside
  # carried over from a previous navigation.
  def handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["blocked", "ghosted", "silenced"] do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: String.capitalize(tab),
       selected_tab: tab,
       id: params["id"],
       section: params["section"],
       page_header_aside: nil
     )}
  end

  def handle_params(%{"tab" => "preferences" = tab} = params, _url, socket) do
    id = params["id"]

    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Default User Preferences"),
       selected_tab: tab,
       id: id,
       page_header_aside: [
         {Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive,
          [
            scope: :instance,
            id: id
          ]}
       ]
     )}
  end

  def handle_params(%{"tab" => "bonfire_" <> extension_shortname = tab}, _url, socket) do
    extension = Bonfire.Common.ExtensionModule.extension(tab)

    {:noreply,
     assign(
       socket,
       back: true,
       page_title: e(extension, :name, nil) || String.capitalize(extension_shortname),
       selected_tab: tab,
       page_header_aside: [
         {Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive,
          [
            selected_tab: tab,
            scope: :instance
          ]}
       ]
     )}
  end

  def handle_params(%{"tab" => "members"}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Local Members"),
       selected_tab: "members"
     )}
  end

  def handle_params(%{"tab" => "remote_users"}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Remote Users"),
       selected_tab: "remote_users"
     )}
  end

  def handle_params(%{"tab" => "remote_instances"}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Remote Instances"),
       selected_tab: "remote_instances"
     )}
  end

  # the instance's widgets, one place per tab: members' dashboard (default) or the homepage for visitors (`?place=home`)
  def handle_params(%{"tab" => "dashboard"} = params, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Widgets"),
       selected_tab: "dashboard",
       place: if(params["place"] == "home", do: "home", else: "dashboard")
     )}
  end

  def handle_params(%{"tab" => "federation_status"}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Federation Status"),
       selected_tab: "federation_status"
     )}
  end

  def handle_params(%{"tab" => tab} = params, _url, socket) do
    extension = Bonfire.Common.ExtensionModule.extension(tab)

    {:noreply,
     assign(
       socket,
       back: true,
       page_title: e(extension, :name, nil) || String.capitalize(tab),
       selected_tab: tab,
       id: params["id"],
       section: params["section"],
       page_header_aside: [
         {Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive,
          [
            selected_tab: tab,
            scope: :instance
          ]}
       ]
     )}
  end

  def handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  @doc """
  Clears the saved copies of the homepage and About page that visitors are served, so they see the instance's widget changes now. Admins only.

  That's the pages saved on disk (`Bonfire.UI.Common.StaticGenerator`, which guests are always served from when a page is saved there), cleared right away, and any proxy or CDN set up (`Bonfire.Common.Cache.HTTPPurge`).
  """
  def handle_event("refresh_homepage", _params, socket) do
    if maybe_apply(Bonfire.Me.Accounts, :is_admin?, [socket.assigns[:__context__]],
         fallback_return: nil
       ) == true do
      urls = ["/", "/about"]
      Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator.bust_urls(urls)

      for adapter <- Bonfire.Common.Cache.HTTPPurge.adapters(),
          adapter != Bonfire.UI.Common.Cache.HTTPPurge.StaticGenerator do
        Task.start(fn -> adapter.bust_urls(urls) end)
      end

      {:noreply, assign_flash(socket, :info, l("Visitors will see your changes now."))}
    else
      {:noreply, assign_flash(socket, :error, l("Only admins can do this."))}
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # Catch-all for events from child components
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end
end
