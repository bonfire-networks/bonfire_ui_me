defmodule Bonfire.UI.Me.CharacterLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Integration
  import Untangle

  # alias Bonfire.Me.Fake
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.UI.Me.ProfileLive

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.LoadCurrentUserCircles,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(_params, _session, socket) do
    # info(params)
    {:ok,
     socket
     |> assign(ProfileLive.default_assigns())
     |> assign_new(:selected_tab, fn -> "timeline" end)}
  end

  def do_handle_params(params, url, socket) do
    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    user_etc =
      case Map.get(params, "username") || Map.get(params, "id") do
        nil ->
          current_user

        username when username == current_username ->
          current_user

        "@" <> username ->
          "/@" <> username

        "+" <> username ->
          "/+" <> username

        "&" <> username ->
          "/&" <> username

        username ->
          # TODO: really need to query here?
          ProfileLive.get(username)
      end
      |> debug("user_etc")

    if user_etc do
      if is_binary(user_etc) do
        debug("redir to correct profile path")

        {:noreply,
         redirect_to(
           socket,
           user_etc
         )}
      else
        if current_user || Integration.is_local?(user_etc) do
          debug("show profile locally")

          redirect_to_path =
            case path(user_etc) do
              "/discussion/" <> _ -> false
              "/character/" <> _ -> false
              path -> path
            end
            |> debug(url)

          current_url = current_url(socket) || maybe_get(URI.parse(url), :path)

          if redirect_to_path && current_url != redirect_to_path do
            {:noreply,
             redirect_to(
               socket,
               path(user_etc)
             )}
          else
            debug("show a simple fallback profile")

            {:noreply,
             socket
             |> assign_flash(
               :info,
               l(
                 "The extension needed to display this doesn't seem installed or enabled. Showing a simplified profile instead..."
               )
             )
             |> assign(ProfileLive.user_assigns(user_etc, current_username))}
          end
        else
          debug("redir to remote profile")

          {:noreply,
           redirect(socket,
             external: canonical_url(user_etc)
           )}
        end
      end
    else
      {:noreply,
       socket
       |> assign_flash(:error, l("Not found"))
       |> redirect_to(path(:error))}
    end
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

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
