defmodule Bonfire.UI.Me.InstanceSettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  # import Untangle

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Instance Settings"),
       back: true,
       nav_items: Bonfire.Common.ExtensionModule.default_nav(:bonfire_ui_social),
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
       selected_tab: "instance_dashboard",
       id: nil,
       #  smart_input_opts: %{hide_buttons: true},
       page: "instance_settings",
       trigger_submit: false,
       scope: :instance
     )}

    # |> IO.inspect
  end

  def do_handle_params(%{"tab" => "preferences" = tab} = params, _url, socket) do
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

  def do_handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       page_title: tab,
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
