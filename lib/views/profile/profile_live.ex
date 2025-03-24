defmodule Bonfire.UI.Me.ProfileLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  use_if_enabled(Bonfire.UI.Common.Web.Native, :view)
  import Untangle

  # alias Bonfire.Me.Integration
  alias Bonfire.Me.Profiles.LiveHandler

  declare_extension("UI for accounts, user profiles and settings",
    icon: "carbon:user-avatar",
    emoji: "🧑🏼",
    description:
      l(
        "User interface for signing in, creating, editing and viewing accounts, user profiles, and settings."
      )
  )

  declare_nav_link(l("Profile"),
    page: "profile",
    icon: "carbon:user-filled",
    icon_active: "carbon:user-filled"
  )

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(
        %{"remote_follow" => _, "username" => _username} = _params,
        _session,
        socket
      ) do
    # TODO?
    {:ok,
     socket
     |> assign(LiveHandler.default_assigns(is_nil(current_user_id(assigns(socket)))))}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(LiveHandler.default_assigns(is_nil(current_user_id(assigns(socket)))))}
  end

  def handle_params(params, uri, socket),
    do:
      handle_profile_params(
        params,
        uri,
        maybe_init(params, socket)
      )

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> nil
    end
    |> debug(selected_tab)
  end

  defp maybe_init(
         %{"username" => load_username} = _params,
         %{assigns: %{user: %{character: %{username: loaded_username}}}} = socket
       )
       when load_username == loaded_username do
    debug(loaded_username, "skip (re)loading same user")

    socket
  end

  defp maybe_init(params, socket) do
    LiveHandler.init(params, socket)
  end

  # def handle_info({:block_status, result}, socket) do
  #   IO.inspect(result, label: "API CALL DONE")
  #   {:noreply, assign(socket, block_status: result)}
  # end

  # def handle_profile_params(%{"tab" => tab} = params, _url, socket)
  #     when tab in ["posts", "boosts", "timeline", "objects"] do
  #   debug(tab, "load tab")

  #   Bonfire.Social.Feeds.LiveHandler.user_feed_assign_or_load_async(
  #     tab,
  #     nil,
  #     params,
  #     socket
  #   )
  # end

  # WIP: Include circles in profile without redirecting to circles page
  # def handle_profile_params(%{"tab" => tab} = params, _url, socket)
  #     when tab in ["circles"] do
  #   debug(tab, "load tab")
  #   current_user = current_user(assigns(socket))
  #   user = e(assigns(socket), :user, nil)
  #   circles =
  #     Bonfire.Boundaries.Circles.list_my_with_counts(current_user, exclude_stereotypes: true)
  #     |> repo().maybe_preload(encircles: [subject: [:profile]])

  #     {:noreply,
  #     assign(
  #       socket,
  #       loading: false,
  #       user: user,
  #       showing_within: e(assigns(socket), :showing_within, nil),
  #       selected_tab: "circles",
  #       circles: circles,
  #     )}
  # end

  def handle_profile_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["followers", "followed", "requests", "requested"] do
    # debug(tab, "load tab")
    user = e(assigns(socket), :user, nil)
    debug(user, "user to get #{tab} for")

    {:noreply,
     assign(
       socket,
       maybe_apply(
         Bonfire.Social.Graph.Follows.LiveHandler,
         :load_network,
         [tab, user, params, socket],
         fallback_return: [],
         current_user: current_user(socket)
       )
     )}
  end

  def handle_profile_params(
        %{"username" => "%40" <> username} = _params,
        _url,
        socket
      ) do
    debug("rewrite encoded @ in URL")
    {:noreply, patch_to(socket, "/@" <> String.replace(username, "%40", "@"), replace: true)}
  end

  # def handle_profile_params(%{"tab" => tab} = params, _url, socket) do
  def handle_profile_params(params, _url, socket) do
    {:noreply,
     assign(socket,
       selected_tab: params["tab"] || :timeline,
       feed_filters: Map.put(params, :by, socket.assigns[:user]),
       feed_name: :user_activities,
       loading: false
     )}
  end

  # def handle_profile_params(params, _url, socket) do
  #   if is_nil(current_user_id(assigns(socket))) do
  #     # TODO: configurable by user
  #     debug(params, "load guest default tab")

  #     handle_profile_params(
  #       Map.merge(params || %{}, %{"tab" => "timeline"}),
  #       nil,
  #       socket
  #     )
  #   else
  #     # TODO: configurable
  #     debug(params, "load user default tab")

  #     handle_profile_params(
  #       Map.merge(params || %{}, %{"tab" => "timeline"}),
  #       nil,
  #       socket
  #     )
  #   end
  # end
end
