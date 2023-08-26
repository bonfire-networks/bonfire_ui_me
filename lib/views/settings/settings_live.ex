defmodule Bonfire.UI.Me.SettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  import Untangle
  # import Bonfire.UI.Me.Integration, only: [is_admin?: 1]

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.UserRequired]}

  def mount(_params, _session, socket) do
    # make configurable
    allowed = ~w(.jpg .jpeg .png .gif .svg .tiff .webp)

    {:ok,
     socket
     # |> assign(:without_sidebar,  true)
     |> assign(
       scope: e(socket, :assigns, :live_action, :user),
       page_title: l("Settings"),
       back: true,
       #  without_widgets: true,
       #  without_sidebar: true,
       #  smart_input_opts: %{disable: true}, # Note: do not disable as it prevents preserving input as you browse the app
       nav_items: [Bonfire.UI.Common.SidebarSettingsNavLive.declared_nav()],
       sidebar_widgets: [
         users: [
           secondary: [
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ],
         guests: [
           secondary: nil
         ]
       ],
       selected_tab: "dashboard",
       id: nil,
       #  smart_input_opts: %{hide_buttons: true},
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

  def do_handle_params(%{"tab" => tab, "id" => id}, _url, socket) do
    # debug(id)
    {:noreply,
     assign(socket,
       back: true,
       selected_tab: tab,
       id: id
     )}
  end

  def do_handle_params(%{"tab" => "preferences" = tab}, _url, socket) do
    scope = socket.assigns[:scope]

    {:noreply,
     assign(
       socket,
       back: true,
       page_title: String.capitalize(to_string(scope)) <> " " <> l("Preferences"),
       selected_tab: tab,
       page_header_aside: [
         {Bonfire.UI.Me.SettingsLive.PreferencesHeaderAsideLive,
          [
            scope: scope
          ]}
       ]
     )}
  end

  def do_handle_params(%{"tab" => "shared_user" = tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Team profile"),
       selected_tab: tab
     )}
  end

  def do_handle_params(%{"tab" => "profile" = tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: l("Edit profile"),
       selected_tab: tab
     )}
  end

  def do_handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       back: true,
       page_title: String.capitalize(tab),
       selected_tab: tab
     )}
  end

  def do_handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        socket,
        __MODULE__,
        &do_handle_params/3
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
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
