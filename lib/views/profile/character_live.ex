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
     |> assign(LiveHandler.default_assigns(is_nil(current_user_id(socket))))
     |> assign_new(:selected_tab, fn -> "timeline" end)}
  end

  def handle_params(params, url, socket) do
    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    {prefix, user_etc, username} =
      case maybe_sanitize_path(Map.get(params, "username")) || Map.get(params, "id") do
        nil ->
          {"@", current_user, current_username}

        username when username == current_username ->
          {"@", current_user, current_username}

        "@" <> username ->
          {"@", "/@" <> username, username}

        "+" <> username ->
          {"+", "/+" <> username, username}

        "&" <> username ->
          {"&", "/&" <> username, username}

        username ->
          # TODO: really need to query here?
          {nil, LiveHandler.get(username), username}
      end
      |> debug("user_etc")

    if user_etc do
      current_url = current_url(socket) || maybe_get(URI.parse(url), :path)

      if is_binary(user_etc) and current_url != user_etc do
        debug("redir to correct profile path")

        {:noreply,
         redirect_to(
           socket,
           user_etc
         )}
      else
        user_etc = if is_binary(user_etc), do: LiveHandler.get(username), else: user_etc

        if not is_nil(id(current_user)) or Integration.is_local?(user_etc) or
             id(user_etc) ==
               maybe_apply(Bonfire.Federate.ActivityPub.AdapterUtils, :service_character_id, []) do
          debug("show profile locally")

          maybe_redirect_to_path =
            case path(user_etc) |> maybe_sanitize_path() do
              "/discussion/" <> _ ->
                false

              "/character/" <> _ ->
                false

              "/&" <> username ->
                # workaround for groups bug
                module_enabled?(Bonfire.UI.Groups, current_user) && "/group/" <> username

              maybe_redirect_to_path ->
                maybe_redirect_to_path
            end
            |> debug(url)

          if is_binary(maybe_redirect_to_path) and current_url != maybe_redirect_to_path do
            {:noreply,
             redirect_to(
               socket,
               maybe_redirect_to_path
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
               path: prefix
             )}
          end
        else
          debug("redir to remote profile")

          {:noreply,
           redirect_to(
             socket,
             canonical_url(user_etc),
             type: :maybe_external
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

  defp maybe_sanitize_path(path) when is_binary(path) do
    URI.decode(path)
  end

  defp maybe_sanitize_path(_), do: nil
end
