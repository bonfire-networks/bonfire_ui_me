defmodule Bonfire.UI.Me.InstanceSettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  import Untangle
  # import Bonfire.UI.Me.Integration, only: [is_admin?: 1]

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: l("Instance Settings"),
       back: true,
       nav_items: [Bonfire.UI.Common.InstanceSidebarSettingsNavLive.declared_nav()],
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
       trigger_submit: false
     )}

    # |> IO.inspect
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
