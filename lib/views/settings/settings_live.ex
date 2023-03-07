defmodule Bonfire.UI.Me.SettingsLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  import Untangle
  # import Bonfire.UI.Me.Integration, only: [is_admin?: 1]
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

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
    |> debug(selected_tab)
  end

  defp mounted(_params, _session, socket) do
    # make configurable
    allowed = ~w(.jpg .jpeg .png .gif .svg .tiff .webp)

    {:ok,
     socket
     # |> assign(:without_sidebar,  true)
     |> assign(
       page_title: l("Settings"),
       back: true,
       #  without_widgets: true,
       #  without_sidebar: true,
       #  smart_input_opts: %{disable: true}, # Note: do not disable as it prevents preserving input as you browse the app
       nav_items: [Bonfire.UI.Common.SidebarSettingsNavLive.declared_nav()],
       #  page_header_aside: [
       #    {Bonfire.UI.Me.SettingsViewsLive.HeaderAsideMobileMenuLive, []}
       #  ],
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
        save(type, user, uploaded_media, socket)
      end
    else
      debug("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  defp handle_progress(:image = type, entry, socket) do
    user = current_user_required!(socket)

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
        save(type, user, uploaded_media, socket)
      end
    else
      debug("Skip uploading because we don't know current_user")
      {:noreply, socket}
    end
  end

  def save(:icon, %{} = user, uploaded_media, socket) do
    with {:ok, user} <-
           Bonfire.Me.Users.update(user, %{
             "profile" => %{
               "icon" => uploaded_media,
               "icon_id" => uploaded_media.id
             }
           }) do
      {:noreply,
       socket
       |> assign_global(current_user: deep_merge(user, %{profile: %{icon: uploaded_media}}))
       |> assign_flash(:info, l("Avatar changed!"))}
    end
  end

  def save(:image, %{} = user, uploaded_media, socket) do
    with {:ok, user} <-
           Bonfire.Me.Users.update(user, %{
             "profile" => %{
               "image" => uploaded_media,
               "image_id" => uploaded_media.id
             }
           }) do
      {:noreply,
       socket
       |> assign_global(current_user: deep_merge(user, %{profile: %{image: uploaded_media}}))
       |> assign_flash(:info, l("Background image changed!"))}
    end
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
