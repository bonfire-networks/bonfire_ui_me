defmodule Bonfire.UI.Me.CharacterLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Integration
  import Untangle

  # alias Bonfire.Me.Fake

  alias Bonfire.Me.Profiles.LiveHandler

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, _session, socket) do
    # info(params)
    {:ok,
     socket
     |> assign(LiveHandler.default_assigns(is_nil(current_user_id(socket.assigns))))
     |> assign_new(:selected_tab, fn -> "timeline" end)}
  end

  def handle_params(params, url, socket) do
    current_user = current_user(socket.assigns)
    current_username = e(current_user, :character, :username, nil)

    {path, user_etc} =
      case Map.get(params, "username") || Map.get(params, "id") do
        nil ->
          {"@", current_user}

        username when username == current_username ->
          {"@", current_user}

        "@" <> username ->
          {"@", "/@" <> username}

        "+" <> username ->
          {"+", "/+" <> username}

        "&" <> username ->
          {"&", "/&" <> username}

        username ->
          # TODO: really need to query here?
          {"@", LiveHandler.get(username)}
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
        if not is_nil(id(current_user)) or Integration.is_local?(user_etc) or
             id(user_etc) == Bonfire.Me.Users.remote_fetcher_id() do
          debug("show profile locally")

          redirect_to_path =
            case path(user_etc) do
              "/discussion/" <> _ ->
                false

              "/character/" <> _ ->
                false

              "/%26" <> username ->
                module_enabled?(Bonfire.UI.Groups, current_user) && "/group/" <> username

              path ->
                path
            end
            |> debug(url)

          current_url = current_url(socket) || maybe_get(URI.parse(url), :path)

          if redirect_to_path && current_url != redirect_to_path do
            {:noreply,
             redirect_to(
               socket,
               redirect_to_path
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
             |> assign(LiveHandler.user_assigns(user_etc, current_user))
             |> assign(
               character_type: :unknown,
               path: path
             )}
          end
        else
          debug("redir to remote profile")

          {:noreply,
           redirect_to(
             socket,
             canonical_url(user_etc)
           )}
        end
      end
    else
      {:noreply,
       socket
       |> assign_flash(:error, l("Not found"))
       |> redirect_to(path(:error, :not_found))}
    end
  end
end
