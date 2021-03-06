defmodule Bonfire.UI.Me.SettingsLive do
  use Bonfire.UI.Common.Web, :surface_view
  import Where
  import Bonfire.UI.Me.Integration, only: [is_admin?: 1]
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      LivePlugs.UserRequired,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(_params, _session, socket) do
    allowed = ~w(.jpg .jpeg .png .gif .svg .tiff .webp) # make configurable
    {:ok,
      socket
      # |> assign(:without_sidebar,  true)
      |> assign(
        sidebar_widgets: [
          users: [
            main: [
              {Bonfire.UI.Me.SettingsViewLive.SidebarSettingsLive,
              [
                selected_tab: "user",
                admin_tab: "",
                current_user: current_user(socket)
              ]}
            ],
            secondary: secondary_widgets()
          ]
        ],
        show_less_menu_items: true,
        page_title: l( "Settings"),
        page_header_aside: [
          {Bonfire.UI.Me.SettingsViewsLive.HeaderAsideMobileMenuLive, []}
        ],
        selected_tab: "user",
        tab_id: "",
        hide_smart_input: true,
        page: "settings",
        trigger_submit: false,
        uploaded_files: []
      )
      |> allow_upload(:icon,
        accept: allowed,
        max_file_size: 5_000_000, # make configurable, expecially once we have resizing
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
      |> allow_upload(:image,
        accept: allowed,
        max_file_size: 10_000_000, # make configurable, expecially once we have resizing
        max_entries: 1,
        auto_upload: true,
        progress: &handle_progress/3
      )
    } # |> IO.inspect
  end
  defp handle_progress(:icon = type, entry, socket) do

    user = current_user(socket)
    scope = if e(socket, :assigns, :selected_tab, nil)=="admin", do: :instance, else: user

    if user && entry.done? do
      with %{} = uploaded_media <-
        maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = metadata ->
          # debug(metadata, "icon consume_uploaded_entry meta")
          Bonfire.Files.IconUploader.upload(user, path, %{client_name: entry.client_name, metadata: metadata[entry.ref]})
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
    user = current_user(socket)
    scope = if e(socket, :assigns, :selected_tab, nil)=="admin", do: :instance, else: user

    if user && entry.done? do
      with %{} = uploaded_media <-
        maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = metadata ->
          # debug(metadata, "image consume_uploaded_entry meta")
          Bonfire.Files.BannerUploader.upload(user, path, %{client_name: entry.client_name, metadata: metadata[entry.ref]})
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

  def secondary_widgets, do: [
            # {Bonfire.UI.Me.WidgetTagsLive , []},
            {Bonfire.UI.Common.WidgetInstanceInfoLive, []},
            {Bonfire.UI.Common.WidgetFeedbackLive, []}
          ]

  def save(:icon, :instance, uploaded_media, socket) do
    with :ok <- Bonfire.Me.Settings.put([:bonfire, :ui, :theme, :instance_icon], Bonfire.Files.IconUploader.remote_url(uploaded_media), scope: :instance, socket: socket) do
      {:noreply, socket
        |> assign_flash(:info, l "Icon changed!")
        |> redirect_to("/")
      }
    end
  end

  def save(:image, :instance, uploaded_media, socket) do
    with :ok <- Bonfire.Me.Settings.put([:bonfire, :ui, :theme, :instance_image], Bonfire.Files.BannerUploader.remote_url(uploaded_media), scope: :instance, socket: socket) do
      {:noreply,
      socket
        |> assign_flash(:info, l "Image changed!")
        |> redirect_to("/")
      }
    end
  end


  def save(:icon, %{} = user, uploaded_media, socket) do
    with {:ok, user} <- Bonfire.Me.Users.update(user, %{"profile"=> %{"icon"=> uploaded_media, "icon_id"=> uploaded_media.id}}) do
      {:noreply, socket
      |> assign(current_user: deep_merge(user, %{profile: %{icon: uploaded_media}}))
      |> assign_flash(:info, l "Avatar changed!")}
    end
  end

  def save(:image, %{} = user, uploaded_media, socket) do
    with {:ok, user} <- Bonfire.Me.Users.update(user, %{"profile"=> %{"image"=> uploaded_media, "image_id"=> uploaded_media.id}}) do
      {:noreply,
      socket
      |> assign(current_user: deep_merge(user, %{profile: %{image: uploaded_media}}))
      |> assign_flash(:info, l "Background image changed!")}
    end
  end



  def do_handle_params(%{"tab" => tab, "id" => id}, _url, socket) do
    # debug(id)
    {:noreply, assign(socket,
      selected_tab: tab,
      tab_id: id,
      sidebar_widgets: [
        users: [
          main: [
            {Bonfire.UI.Me.SettingsViewLive.SidebarSettingsLive,
            [
              selected_tab: tab,
              admin_tab: id,
              current_user: current_user(socket)
            ]}
          ],
          secondary: secondary_widgets()
        ]
      ]
      )}
  end

  # def do_handle_params(%{"tab" => tab, "admin_tab" => admin_tab}, _url, socket) do
  #   debug(admin_tab)
  #   {:noreply, assign(socket, selected_tab: tab, admin_tab: admin_tab)}
  # end

  def do_handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply, assign(
        socket,
        selected_tab: tab,
        sidebar_widgets: [
          users: [
            main: [
              {Bonfire.UI.Me.SettingsViewLive.SidebarSettingsLive,
              [
                selected_tab: tab,
                admin_tab: "",
                current_user: current_user(socket)
              ]}
            ],
            secondary: secondary_widgets()
          ]
        ]
        )}
  end

  def do_handle_params(_, _url, socket) do
    {:noreply, socket}
  end

  def handle_params(params, uri, socket) do
    # poor man's hook I guess
    with {_, socket} <- Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket) do
      undead_params(socket, fn ->
        do_handle_params(params, uri, socket)
      end)
    end
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)

end
