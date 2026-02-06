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
       selected_tab: "instance_dashboard",
       id: nil,
       page: "instance_settings",
       trigger_submit: false,
       scope: :instance
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

  def handle_params(%{"tab" => "federation_status"}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Federation Status"),
       selected_tab: "federation_status"
     )}
  end

  def handle_params(%{"tab" => tab}, _url, socket) do
    extension = Bonfire.Common.ExtensionModule.extension(tab)

    {:noreply,
     assign(
       socket,
       back: true,
       page_title: e(extension, :name, nil) || String.capitalize(tab),
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

  def handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # Catch-all for events from child components
  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end
end
