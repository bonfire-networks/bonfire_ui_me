defmodule Bonfire.UI.Me.ProfileLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Integration
  import Untangle

  # alias Bonfire.Me.Fake
  # declare_nav_link(l("Profile"), page: "profile", icon: "ri:user-line", icon_active: "ri:user-fill")

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(
        %{"remote_follow" => _, "username" => _username} = _params,
        _session,
        socket
      ) do
    # TODO?
    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    # debug(params)
    {:ok,
     socket
     |> assign(default_assigns(is_nil(current_user_id(socket.assigns))))}
  end

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
    |> debug(selected_tab)
  end

  defp maybe_init(
         %{"username" => load_username} = _params,
         %{assigns: %{user: %{character: %{username: loaded_username}}}} = socket
       )
       when load_username == loaded_username do
    debug("skip (re)loading user")
    debug(loaded_username, "old user")
    debug(load_username, "load new user")
    socket
  end

  defp maybe_init(params, socket) do
    init(params, socket)
  end

  defp init(params, socket) do
    debug(params)
    username = Map.get(params, "username") || Map.get(params, "id")

    current_user = current_user(socket.assigns)
    current_username = e(current_user, :character, :username, nil)

    user =
      (params[:user] ||
         case username do
           nil ->
             current_user

           username when username == current_username ->
             current_user

           "@" <> username ->
             get(username)

           username ->
             get(username)
         end)
      |> repo().maybe_preload([:shared_user, :settings])

    # debug(user)

    user_id = id(user)

    # show remote users only to logged in users
    if user_id &&
         (id(current_user) || Integration.is_local?(user) ||
            user_id == Bonfire.Me.Users.remote_fetcher()) do
      # debug(
      #   Bonfire.Boundaries.Controlleds.list_on_object(user),
      #   "boundaries on user profile"
      # )

      follows_me =
        current_user && id(current_user) != user_id &&
          module_enabled?(Bonfire.Social.Graph.Follows, current_user) &&
          Utils.maybe_apply(
            Bonfire.Social.Graph.Follows,
            :following?,
            [user, current_user]
          )

      # situation = Bonfire.Boundaries.Blocks.LiveHandler.preload([%{__context__: socket.assigns.__context__, id: id(user), object_id: id(user), object: user, current_user: current_user}], caller_module: __MODULE__)
      # IO.inspect(situation, label: "situation2")
      # smart_input_prompt = if current_username == e(user, :character, :username, ""), do: l( "Write something..."), else: l("Write something for ") <> e(user, :profile, :name, l("this person"))
      # smart_input_prompt = nil

      # smart_input_text =
      #   if current_username == e(user, :character, :username, ""),
      #     do: "",
      #     else: "@" <> e(user, :character, :username, "") <> " "

      # preload(user, socket)
      socket
      |> assign(user_assigns(user, current_user, follows_me))
      |> assign_new(:selected_tab, fn -> "timeline" end)
      |> assign(:character_type, :user)
      |> assign(:ghosted, nil)

      # |> assign_global(
      # following: following || [],
      # search_placeholder: search_placeholder,
      # smart_input_opts: %{prompt: smart_input_prompt, text_suggestion: smart_input_text}

      # to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), ulid(user)}]
      # )
    else
      if user do
        # redir to login and then come back to this page
        # redir to remote profile
        if Map.get(params, "remote_interaction") do
          path = path(user)

          socket
          |> set_go_after(path)
          |> assign_flash(
            :info,
            l("Please login first, and then... ") <>
              " " <> e(socket, :assigns, :flash, :info, "")
          )
          |> redirect_to(path(:login) <> go_query(path))
        else
          redirect(socket,
            external: canonical_url(user)
          )
        end
      else
        #  remote actor
        with true <- String.trim(username, "@") |> String.contains?("@"),
             {:ok, user} <-
               Utils.maybe_apply(
                 Bonfire.Federate.ActivityPub.AdapterUtils,
                 :get_or_fetch_and_create_by_username,
                 [username]
               ) do
          init(params |> Map.put(:user, user), socket)
        else
          _ ->
            socket
            |> assign_flash(:error, l("Profile not found"))
            |> redirect_to(path(:error, :not_found))
        end
      end
    end
  end

  # defp preload(user, socket) do
  #   view_pid = self()
  #   # Here we're checking if the user is ghosted / silenced by user or instance
  #   IO.inspect("preload test")
  #   apply_task(:start_link, fn ->
  #     ghosted? = Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, current_user: current_user(socket.assigns)) |> debug("ghosted?")
  #     ghosted_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide) |> debug("ghosted_instance_wide?")
  #     silenced? = Bonfire.Boundaries.Blocks.is_blocked?(user, :silence, current_user: current_user(socket.assigns)) |> debug("silenced?")
  #     silenced_instance_wide? = Bonfire.Boundaries.Blocks.is_blocked?(user, :silence, :instance_wide) |> debug("silenced_instance_wide?")
  #     result = %{
  #       ghosted?: ghosted?,
  #       ghosted_instance_wide?: ghosted_instance_wide?,
  #       silenced?: silenced?,
  #       silenced_instance_wide?: silenced_instance_wide?
  #     }
  #     send(view_pid, {:block_status, result})
  #   end)

  # end

  # def handle_info({:block_status, result}, socket) do
  #   IO.inspect(result, label: "API CALL DONE")
  #   {:noreply, assign(socket, block_status: result)}
  # end

  def get(username) do
    username =
      String.trim_trailing(
        username,
        "@" <> Bonfire.Common.URIs.base_domain()
      )

    with {:ok, user} <- Bonfire.Me.Users.by_username(username, preload: :profile) do
      user
    else
      _ ->
        # handle other character types beyond User
        with {:ok, character} <- Bonfire.Common.Needles.get(username) do
          character
        else
          _ ->
            nil
        end
    end
    |> debug("theuser")
  end

  def default_assigns(is_guest?) do
    [
      is_guest?: is_guest?,
      without_sidebar: is_guest?,
      without_secondary_widgets: is_guest?,
      no_header: is_guest?,
      hide_tabs: is_guest?,
      smart_input: true,
      feed: nil,
      page_info: [],
      page: "profile",
      page_title: l("Profile"),
      feed_title: l("User timeline"),
      back: true,
      # without_sidebar: true,
      # the user to display
      nav_items: Bonfire.Common.ExtensionModule.default_nav(),
      user: %{},
      canonical_url: nil,
      character_type: nil,
      path: "@",
      sidebar_widgets: [
        guests: [
          secondary: [
            {Bonfire.Tag.Web.WidgetTagsLive, []},
            {Bonfire.UI.Me.WidgetAdminsLive, []}
          ]
        ],
        users: [
          secondary: [
            {Bonfire.Tag.Web.WidgetTagsLive, []},
            {Bonfire.UI.Me.WidgetAdminsLive, []}
          ]
        ]
      ],
      interaction_type: l("follow"),
      follows_me: false,
      no_index: false,
      boundary_preset: nil
    ]
  end

  def user_assigns(user, current_user, follows_me \\ false) do
    name = e(user, :profile, :name, l("Someone"))

    # viewing_username = e(user, :character, :username, "")

    title =
      if id(current_user) == id(user),
        do: l("Your profile"),
        else: name

    # my_follow =
    #     current_user && id(current_user) != id(user) &&
    #       module_enabled?(Bonfire.Social.Graph.Follows, current_user) &&
    #       Bonfire.Social.Graph.Follows.following?(current_user, user)

    # search_placeholder = if current_username == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"
    [
      page_title: title,
      user: user,
      canonical_url: canonical_url(user),
      name: name,
      follows_me: follows_me,
      no_index:
        Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], false,
          current_user: user
        )
    ]
  end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["posts", "boosts", "timeline", "objects"] do
    debug(tab, "load tab")

    Bonfire.Social.Feeds.LiveHandler.user_feed_assign_or_load_async(
      tab,
      nil,
      params,
      socket
    )
  end

  # WIP: Include circles in profile without redirecting to circles page
  # def do_handle_params(%{"tab" => tab} = params, _url, socket)
  #     when tab in ["circles"] do
  #   debug(tab, "load tab")
  #   current_user = current_user(socket.assigns)
  #   user = e(socket, :assigns, :user, nil)
  #   circles =
  #     Bonfire.Boundaries.Circles.list_my_with_counts(current_user, exclude_stereotypes: true)
  #     |> repo().maybe_preload(encircles: [subject: [:profile]])

  #     {:noreply,
  #     assign(
  #       socket,
  #       loading: false,
  #       user: user,
  #       showing_within: e(socket, :assigns, :showing_within, nil),
  #       selected_tab: "circles",
  #       circles: circles,
  #     )}
  # end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["followers", "followed", "requests", "requested"] do
    debug(tab, "load tab")

    {:noreply,
     Bonfire.Social.Feeds.LiveHandler.assign_feed(
       socket,
       Bonfire.Social.Feeds.LiveHandler.load_user_feed_assigns(
         tab,
         nil,
         params,
         socket
       )

       # |> debug("ffff")
     )}
  end

  def do_handle_params(
        %{"username" => "%40" <> username} = _params,
        _url,
        socket
      ) do
    debug("rewrite encoded @ in URL")
    {:noreply, patch_to(socket, "/@" <> String.replace(username, "%40", "@"), replace: true)}
  end

  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
    debug(tab, "unknown tab, maybe from another extension?")

    {:noreply,
     assign(socket,
       selected_tab: tab
     )}
  end

  def do_handle_params(params, _url, socket) do
    if is_nil(current_user_id(socket.assigns)) do
      debug(params, "load guest default tab")

      do_handle_params(
        Map.merge(params || %{}, %{"tab" => "posts"}),
        nil,
        socket
      )
    else
      debug(params, "load user default tab")

      do_handle_params(
        Map.merge(params || %{}, %{"tab" => "timeline"}),
        nil,
        socket
      )
    end
  end

  def handle_params(params, uri, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_params(
        params,
        uri,
        maybe_init(params, socket),
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
