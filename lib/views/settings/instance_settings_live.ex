defmodule Bonfire.UI.Me.InstanceSettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  import Untangle
  import Bonfire.UI.Me.Integration, only: [is_admin?: 1]
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(_params, _session, socket) do
    # make configurable
    allowed = ~w(.jpg .jpeg .png .gif .svg .tiff .webp)

    {:ok,
     socket
     |> assign(
       page_title: l("Instance Settings"),
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
       selected_tab: "dashboard",
       id: nil,
       #  smart_input_opts: [hide_buttons: true],
       page: "instance_settings",
       trigger_submit: false,
       uploaded_files: []
     )
     |> allow_upload(:icon,
       accept: allowed,
       # make configurable, expecially once we have resizing
       max_file_size: 5_000_000,
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> allow_upload(:image,
       accept: allowed,
       # make configurable, expecially once we have resizing
       max_file_size: 10_000_000,
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )}

    # |> IO.inspect
  end

  defp handle_progress(:icon = type, entry, socket) do
    user = current_user_required!(socket)

    scope =
      if e(socket, :assigns, :selected_tab, nil) == "admin",
        do: :instance,
        else: user

    if user && entry.done? do
      with %{} = uploaded_media <-
             maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = metadata ->
               # debug(metadata, "icon consume_uploaded_entry meta")
               Bonfire.Files.IconUploader.upload(user, path, %{
                 client_name: entry.client_name,
                 metadata: metadata[entry.ref]
               })

               # |> debug("uploaded")
             end) do
        # debug(uploaded_media)
        save(type, scope, uploaded_media, socket)
      end
    else
      debug("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  defp handle_progress(:image = type, entry, socket) do
    user = current_user_required!(socket)

    scope =
      if e(socket, :assigns, :selected_tab, nil) == "admin",
        do: :instance,
        else: user

    if user && entry.done? do
      with %{} = uploaded_media <-
             maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = metadata ->
               # debug(metadata, "image consume_uploaded_entry meta")
               Bonfire.Files.BannerUploader.upload(user, path, %{
                 client_name: entry.client_name,
                 metadata: metadata[entry.ref]
               })

               # |> debug("uploaded")
             end) do
        # debug(uploaded_media)
        save(type, scope, uploaded_media, socket)
      end
    else
      debug("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  def save(:icon, :instance, uploaded_media, socket) do
    with :ok <-
           Bonfire.Me.Settings.put(
             [:bonfire, :ui, :theme, :instance_icon],
             Bonfire.Files.IconUploader.remote_url(uploaded_media),
             scope: :instance,
             socket: socket
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Icon changed!"))
       |> redirect_to("/")}
    end
  end

  def save(:image, :instance, uploaded_media, socket) do
    with :ok <-
           Bonfire.Me.Settings.put(
             [:bonfire, :ui, :theme, :instance_image],
             Bonfire.Files.BannerUploader.remote_url(uploaded_media),
             scope: :instance,
             socket: socket
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Image changed!"))
       |> redirect_to("/")}
    end
  end

  def do_handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply,
     assign(
       socket,
       selected_tab: tab
     )}
  end

  def do_handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", _params, socket) do
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
