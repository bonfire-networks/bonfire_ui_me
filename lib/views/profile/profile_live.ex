defmodule Bonfire.UI.Me.ProfileLive do
  use Bonfire.UI.Common.Web, :surface_view
  alias Bonfire.Me.Integration
  import Where

  # alias Bonfire.Me.Fake
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.LoadCurrentUserCircles,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ]
  end

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end
  end

  defp mounted(%{"remote_follow"=> _, "username"=> _username} = _params, _session, _socket) do
    # TODO?
  end

  defp mounted(params, _session, socket) do
    # info(params)

    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    user = case Map.get(params, "username") do
      nil ->
        current_user

      username when username == current_username ->
        current_user

      "@"<>username ->
        get_user(username)
      username ->
        get_user(username)
    end
    |> repo().maybe_preload(:shared_user)

    # debug(user)

    if user && ( current_username || Integration.is_local?(user) ) do # show remote users only to logged in users

      dump(Bonfire.Boundaries.Controlleds.list_on_object(user), "boundaries on user profile")

      following = current_user && current_user.id != user.id && module_enabled?(Bonfire.Social.Follows) && Bonfire.Social.Follows.following?(user, current_user)

      page_title = if current_username == e(user, :character, :username, ""), do: l( "Your profile"), else: e(user, :profile, :name, l "Someone") <> "'s profile"

      # smart_input_prompt = if current_username == e(user, :character, :username, ""), do: l( "Write something..."), else: l("Write something for ") <> e(user, :profile, :name, l("this person"))
      smart_input_prompt = nil
      smart_input_text = if current_username == e(user, :character, :username, ""), do:
      "", else: "@"<>e(user, :character, :username, "")<>" "

      # search_placeholder = if current_username == e(user, :character, :username, ""), do: "Search my profile", else: "Search " <> e(user, :profile, :name, "this person") <> "'s profile"
      {:ok,
        socket
        |> assign(
          page: "profile",
          page_title: page_title,
          selected_tab: "timeline",
          smart_input: true,
          feed_title: l( "User timeline"),
          user: user, # the user to display
          feed: [],
          follows_me: following,
          page_info: [],
          no_index: !Bonfire.Me.Settings.get([Bonfire.Me.Users, :discoverable], true, current_user: user)
        )
      |> assign_global(
        # following: following || [],
        # search_placeholder: search_placeholder,
        smart_input_prompt: smart_input_prompt,
        smart_input_text: smart_input_text
        # to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}]
      )}
    else
      if user do
        if Map.get(params, "remote_interaction") do # redir to login and then come back to this page
          path = path(user)
          {:ok,
            socket
            |> set_go_after(path)
            |> assign_flash(:info, l("Please login first, and then... ")<>" "<>e(socket, :assigns, :flash, :info, ""))
            |> redirect_to(path(:login) <> go_query(path))
          }
        else # redir to remote profile
          {:ok,
            socket
            |> redirect(external: canonical_url(user))
          }
        end
      else
        {:ok,
          socket
          |> assign_flash(:error, l "Profile not found")
          |> redirect_to(path(:error))
        }
      end
    end
  end

  def get_user(username) do
    username = String.trim_trailing(username, "@"<>Bonfire.Common.URIs.instance_domain())

    with {:ok, user} <- Bonfire.Me.Users.by_username(username) do
      user
    else _ -> # handle other character types beyond User
       with {:ok, character} <- Bonfire.Me.Characters.by_username(username) do
        Bonfire.Common.Pointers.get!(character.id) # FIXME? this results in extra queries
      else _ ->
        nil
      end
    end
  end


  def do_handle_params(%{"tab" => tab} = params, _url, socket) when tab in ["posts", "boosts", "timeline"] do
    Bonfire.Social.Feeds.LiveHandler.user_feed_assign_or_load_async(tab, nil, params, socket)
  end


  def do_handle_params(%{"tab" => tab} = params, _url, socket) when tab in ["followers", "followed"] do
    {:noreply,
      assign(socket,
        Bonfire.Social.Feeds.LiveHandler.load_user_feed_assigns(tab, nil, params, socket)
      )}
  end

  # def do_handle_params(%{"tab" => "private" =tab} = _params, _url, socket) do
  #   current_user = current_user(socket)
  #   user = e(socket, :assigns, :user, nil)

  #   page_title = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "My messages"), else: l("Messages with")<>" "<>e(user, :profile, :name, l "someone")

  #   # smart_input_prompt = if e(current_user, :character, :username, "") == e(user, :character, :username, ""), do: l( "Write a private note to self..."), else: l("Send a private message") <> e(user, :profile, :name, l "this person")
  #   smart_input_prompt = l("Send a private message")

  #   smart_input_text = if e(current_user, :character, :username, nil) != e(user, :character, :username, nil),
  #   do: "@"<>e(user, :character, :username, "")<>" ",
  #   else: ""

  #   feed = if current_user, do: if module_enabled?(Bonfire.Social.Messages), do: Bonfire.Social.Messages.list(current_user, user) #|> debug("messages")

  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab,
  #      feed: e(feed, :edges, [])
  #    )
  #   |> assign_global(
  #     page_title: page_title,
  #     smart_input_prompt: smart_input_prompt,
  #     smart_input_text: smart_input_text,
  #     to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), e(user, :id, nil)}],
  #     create_activity_type: :message
  #   )
  #   }
  # end

  def do_handle_params(%{"username" => username} = _params, url, socket) do
    # info(url, "profile url")

    if String.contains?(url, "%40"<>username) do
      debug("rewrite encoded @ in URL")
      {:noreply, patch_to(socket, "/@"<>username, replace: true)}
    else
      do_handle_params(nil, nil, socket) # default tab
    end
  end

  def do_handle_params(%{"tab" => tab} = _params, _url, socket) do
    # something that may be added by another extension?
    {:noreply,
     assign(socket,
       selected_tab: tab
     )}
  end

  def do_handle_params(params, _url, socket) do
    # default tab
    do_handle_params(Map.merge(params || %{}, %{"tab" => "timeline"}), nil, socket)
  end

  def handle_params(params, uri, socket) do
    # poor man's hook I guess
    with {_, socket} <- Bonfire.UI.Common.LiveHandlers.handle_params(params, uri, socket) do
      undead_params(socket, fn ->
        do_handle_params(params, uri, socket)
      end)
    end
  end


  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

end
