defmodule Bonfire.UI.Me.SettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  import Untangle

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.UserRequired]}

  def mount(_params, _session, socket) do
    # make configurable
    _allowed = ~w(.jpg .jpeg .png .gif .svg .tiff .webp)

    {:ok,
     socket
     # |> assign(:without_sidebar,  true)
     |> assign(
       scope: e(assigns(socket), :live_action, :user),
       page_title: l("Settings"),
       #  without_secondary_widgets: true,
       nav_items: [Bonfire.UI.Me.SidebarSettingsNavLive.declared_nav()],
       selected_tab: nil,
       id: nil,
       page: "settings",
       trigger_submit: false,
       uploaded_files: []
     )}

    # |> IO.inspect
  end

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
    |> debug(selected_tab)
  end

  def handle_params(%{"tab" => "preferences" = tab} = params, _url, socket) do
    scope = assigns(socket)[:scope]
    id = params["id"]

    {:noreply,
     assign(
       socket,
       back: true,
       id: id,
       page_title: String.capitalize(to_string(scope)) <> " " <> l("Preferences"),
       selected_tab: tab,
       page_header_aside: [
         {Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive,
          [
            scope: scope,
            id: id
          ]}
       ]
     )}
  end

  def handle_params(%{"tab" => tab, "id" => id}, _url, socket) do
    {:noreply,
     assign(socket,
       back: true,
       selected_tab: tab,
       id: id
     )}
  end

  def handle_params(%{"tab" => "shared_user" = tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Team profiles"),
       selected_tab: tab
     )}
  end

  def handle_params(%{"tab" => "profile" = tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Edit profile"),
       selected_tab: tab
     )
     |> debug()}
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
            scope: assigns(socket)[:scope]
          ]}
       ]
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
            scope: assigns(socket)[:scope]
          ]}
       ]
     )}
  end

  def handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       selected_tab: tab,
       page_header_aside: [
         {Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive,
          [
            selected_tab: tab,
            scope: assigns(socket)[:scope]
          ]}
       ]
     )}
  end

  def handle_params(_, url, socket) when is_binary(url) do
    if String.contains?(url, "/settings/account") do
      {:noreply, assign(socket, selected_tab: "account")}
    else
      {:noreply, socket}
    end
  end

  def handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end
end
