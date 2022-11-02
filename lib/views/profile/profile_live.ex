defmodule Bonfire.UI.Me.ProfileLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Integration
  import Untangle

  # alias Bonfire.Me.Fake
  alias Bonfire.UI.Me.LivePlugs

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

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
    |> debug(selected_tab)
  end

  defp mounted(
         %{"remote_follow" => _, "username" => _username} = _params,
         _session,
         _socket
       ) do
    # TODO?
  end

  defp mounted(params, _session, socket) do
    # debug(params)
    {:ok, init(params, socket)}
  end

  defp init(params, socket) do
    # info(params)

    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    user =
      case Map.get(params, "username") do
        nil ->
          current_user

        username when username == current_username ->
          current_user

        "@" <> username ->
          get_user(username)

        username ->
          get_user(username)
      end
      |> repo().maybe_preload(:shared_user)

    # debug(user)

    # show remote users only to logged in users
    if user && (current_username || Integration.is_local?(user)) do
      debug(
        Bonfire.Boundaries.Controlleds.list_on_object(user),
        "boundaries on user profile"
      )

      following =
        current_user && current_user.id != user.id &&
          module_enabled?(Bonfire.Social.Follows, current_user) &&
          Bonfire.Social.Follows.following?(user, current_user)

      name = e(user, :profile, :name, l("Someone"))

      title =
        if current_username == e(user, :character, :username, ""),
          do: l("Your profile"),
          else: name <> "'s profile"

      # smart_input_prompt = if current_username == e(user, :character, :username, ""), do: l( "Write something..."), else: l("Write something for ") <> e(user, :profile, :name, l("this person"))
      smart_input_prompt = nil

      smart_input_text =
        if current_username == e(user, :character, :username, ""),
          do: "",
          else: "@" <> e(user, :character, :username, "") <> " "

      # search_placeholder = if current_username == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"
      socket
      |> assign_new(:selected_tab, fn -> "timeline" end)
      |> assign(
        smart_input: true,
        feed: nil,
        page_info: [],
        page: "profile",
        page_title: title,
        feed_title: l("User timeline"),
        without_sidebar: false,
        without_mobile_logged_header: true,
        # the user to display
        user: user,
        canonical_url: canonical_url(user),
        name: name,
        interaction_type: l("follow"),
        follows_me: following,
        sidebar_widgets: [
          users: [
            secondary: [
              {Bonfire.UI.Me.WidgetProfileLive, [user: user]},
              {Bonfire.Tag.Web.WidgetTagsLive, []}
            ]
          ],
          guests: [
            secondary: [
              {Bonfire.UI.Me.WidgetProfileLive, [user: user]},
              {Bonfire.Tag.Web.WidgetTagsLive, []}
            ]
          ]
        ],
        no_index:
          Bonfire.Me.Settings.get([Bonfire.Me.Users, :undiscoverable], false, current_user: user)
      )
      |> assign_global(
        # following: following || [],
        # search_placeholder: search_placeholder,
        smart_input_prompt: smart_input_prompt,
        smart_input_opts: [text: smart_input_text]

        # to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), ulid(user)}]
      )
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
        socket
        |> assign_flash(:error, l("Profile not found"))
        |> redirect_to(path(:error))
      end
    end
  end

  defp maybe_init(
         %{"username" => load_username} = params,
         %{assigns: %{user: %{character: %{username: loaded_username}}}} = socket
       )
       when load_username != loaded_username do
    debug(loaded_username, "old user")
    debug(load_username, "load new user")
    init(params, socket)
  end

  defp maybe_init(params, socket) do
    debug("skip (re)loading user")
    socket
  end

  defp get_user(username) do
    username =
      String.trim_trailing(
        username,
        "@" <> Bonfire.Common.URIs.instance_domain()
      )

    # handle other character types beyond User
    with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
      user
    else
      _ ->
        with {:ok, character} <- Bonfire.Me.Characters.by_username(username) do
          # FIXME? this results in extra queries
          Bonfire.Common.Pointers.get!(character.id)
        else
          _ ->
            nil
        end
    end
  end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["posts", "boosts", "timeline"] do
    debug(tab, "load tab")

    Bonfire.Social.Feeds.LiveHandler.user_feed_assign_or_load_async(
      tab,
      nil,
      params,
      socket
    )
  end

  def do_handle_params(%{"tab" => tab} = params, _url, socket)
      when tab in ["followers", "followed"] do
    debug(tab, "load tab")

    {:noreply,
     assign(
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
        url,
        socket
      ) do
    debug("rewrite encoded @ in URL")
    {:noreply, patch_to(socket, "/@" <> username, replace: true)}
  end

  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
    debug(tab, "unknown tab, maybe from another extension?")

    {:noreply,
     assign(socket,
       selected_tab: tab
     )}
  end

  def do_handle_params(params, _url, socket) do
    debug(params, "load default tab")

    do_handle_params(
      Map.merge(params || %{}, %{"tab" => "timeline"}),
      nil,
      socket
    )
  end

  def handle_params(params, uri, socket) do
    undead_params(socket, fn ->
      # in case we're patching to a different user
      maybe_init(params, socket)
      |> do_handle_params(params, uri, ...)
    end)
  end

  def handle_event(action, attrs, socket),
    do:
      Bonfire.UI.Common.LiveHandlers.handle_event(
        action,
        attrs,
        socket,
        __MODULE__
      )

  def handle_info(info, socket),
    do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
