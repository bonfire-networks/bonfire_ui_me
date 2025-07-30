defmodule Bonfire.Me.Profiles.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  # import Bonfire.Common.Text

  # TODO: use Profiles context instead?
  alias Bonfire.Me.Integration
  alias Bonfire.Me.Users

  def handle_event("validate", params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "save",
        _data,
        %{assigns: %{trigger_submit: trigger_submit}} = socket
      )
      when trigger_submit == true do
    {
      :noreply,
      assign(socket, trigger_submit: false)
    }
  end

  def handle_event("save", params, socket) do
    # params = input_to_atoms(params)

    with {:ok, _edit_profile} <-
           Users.update(current_user_required!(socket), params,
             context: assigns(socket)[:__context__] || current_account(socket)
           ) do
      # debug(icon: Map.get(params, "icon"))
      cond do
        # handle controller-based upload
        Text.strlen(Map.get(params, "icon")) > 0 or
            Text.strlen(Map.get(params, "image")) > 0 ->
          {
            :noreply,
            assign(socket, trigger_submit: true)
            |> assign_flash(:info, "Details saved!")
            |> redirect_to("/user")
          }

        true ->
          {:noreply,
           socket
           |> assign_flash(:info, "Profile saved!")
           |> redirect_to("/user")}
      end
    end
  end

  def set_profile_image(:icon, %{} = user, uploaded_media, assign_field, socket) do
    with {:ok, user} <-
           Bonfire.Me.Profiles.set_profile_image(:icon, user, uploaded_media) do
      {:noreply,
       socket
       #  |> assign_global(assign_field, deep_merge(user, %{profile: %{icon: uploaded_media}}))
       |> assign_flash(:info, l("Avatar changed!"))
       |> assign(src: Bonfire.Files.IconUploader.remote_url(uploaded_media))
       |> send_self_global({assign_field, deep_merge(user, %{profile: %{icon: uploaded_media}})})}
    end
  end

  def set_profile_image(:banner, %{} = user, uploaded_media, assign_field, socket) do
    debug(assign_field)

    with {:ok, user} <-
           Bonfire.Me.Profiles.set_profile_image(:banner, user, uploaded_media) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Background image changed!"))
       |> assign(src: Bonfire.Files.BannerUploader.remote_url(uploaded_media))
       #  |> assign_global(assign_field, deep_merge(user, %{profile: %{image: uploaded_media}}) |> debug)
       |> send_self_global({assign_field, deep_merge(user, %{profile: %{image: uploaded_media}})})}
    end
  end

  def init(username_or_id, params, socket) do
    # debug(params)

    current_user = current_user(socket)
    current_user_id = id(current_user)
    current_username = e(current_user, :character, :username, nil)

    user =
      (params[:user] ||
         case username_or_id do
           nil ->
             #  current_user
             throw("No user to show")

           username when username == current_username ->
             current_user

           "@" <> username ->
             get(username)

           username ->
             get(username)
         end)
      |> repo().maybe_preload([:settings, character: :peered])
      |> repo().maybe_preload([:shared_user])

    # debug(user)

    user_id = id(user)
    username = e(user, :character, :username, nil) || username_or_id
    is_local? = Integration.is_local?(user)

    # show remote users only to logged in users
    if user_id &&
         (current_user_id || is_local? ||
            user_id ==
              maybe_apply(Bonfire.Federate.ActivityPub.AdapterUtils, :service_character_id, [])) do
      # debug(
      #   Bonfire.Boundaries.Controlleds.list_on_object(user),
      #   "boundaries on user profile"
      # )

      follows_me =
        current_user_id && current_user_id != user_id &&
          module_enabled?(Bonfire.Social.Graph.Follows, current_user) &&
          Utils.maybe_apply(
            Bonfire.Social.Graph.Follows,
            :follow_status,
            [user, current_user]
          )

      # situation = Bonfire.Boundaries.Blocks.LiveHandler.preload([%{__context__: assigns(socket).__context__, id: id(user), object_id: id(user), object: user, current_user: current_user}], caller_module: __MODULE__)
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
      |> maybe_assign_aliases(user)
      |> assign(Bonfire.Boundaries.Blocks.LiveHandler.preload_one(user, current_user))
      |> assign_new(:selected_tab, fn -> :timeline end)
      |> assign(
        character_type: :user,
        no_mobile_header: true,
        is_local?: is_local?
      )

      # |> assign_global(
      # following: following || [],
      # search_placeholder: search_placeholder,
      # smart_input_opts: %{prompt: smart_input_prompt, text_suggestion: smart_input_text}

      # to_circles: [{e(user, :profile, :name, e(user, :character, :username, l "someone")), uid(user)}]
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
              " " <> e(assigns(socket), :flash, :info, "")
          )
          |> redirect_to(path(:login) <> go_query(path))
        else
          redirect_to(
            socket,
            canonical_url(user),
            type: :maybe_external,
            fallback: "/error"
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
          init(e(user, :character, :username, nil), params |> Map.put(:user, user), socket)
        else
          _ ->
            socket
            |> assign_flash(:error, l("Profile not found"))
            |> redirect_to(path(:error, :not_found))
        end
      end
    end
  end

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
  end

  def default_assigns(_is_guest?) do
    [
      is_guest?: false,
      without_sidebar: false,
      without_secondary_widgets: false,
      no_header: true,
      hide_tabs: false,
      smart_input: true,
      feed: nil,
      aliases: nil,
      page_info: [],
      page: "profile",
      showing_within: :profile,
      page_title: l("Profile"),
      feed_title: l("User timeline"),
      back: true,
      nav_items: Bonfire.Common.ExtensionModule.default_nav(),
      user: %{},
      canonical_url: nil,
      character_type: nil,
      path: "@",
      interaction_type: l("follow"),
      follows_me: false,
      no_index: false,
      boundary_preset: nil,
      silenced_instance_wide?: nil,
      ghosted_instance_wide?: nil,
      ghosted?: nil,
      silenced?: nil,
      selected_tab: nil
    ]
  end

  def user_assigns(user, current_user, follows_me \\ false) do
    name = e(user, :profile, :name, l("Someone"))

    # viewing_username = e(user, :character, :username, "")

    title =
      if id(current_user) == id(user),
        do: l("Your profile"),
        else: name

    weather_widget_enabled =
      Settings.get([Bonfire.Geolocate, :weather], nil, current_user: current_user)

    recent_publication_widget_enabled =
      Settings.get([Bonfire.OpenScience, :widgets, :recent_publication], false, current_user: current_user)

    most_cited_publication_widget_enabled =
      Settings.get([Bonfire.OpenScience, :widgets, :most_cited_publication], false, current_user: current_user)

    author_topics_widget_enabled =
      Settings.get([Bonfire.OpenScience, :widgets, :author_topics], false, current_user: current_user)

    publication_types_widget_enabled =
      Settings.get([Bonfire.OpenScience, :widgets, :publication_types], false, current_user: current_user)

    pandora_public_lists_widget_enabled =
      module_enabled?(Bonfire.PanDoRa.Web.WidgetPublicListsLive, current_user)

    # ^ TODO: only use module_enabled

    sidebar_widgets = [
      guests: [
        secondary: [
          recent_publication_widget_enabled &&
            {Bonfire.OpenScience.RecentPublicationLive, [user: user]},
          most_cited_publication_widget_enabled &&
            {Bonfire.OpenScience.MostCitedPublicationLive, [user: user]},
          author_topics_widget_enabled &&
            {Bonfire.OpenScience.AuthorTopicsLive, [user: user]},
          publication_types_widget_enabled &&
            {Bonfire.OpenScience.PublicationTypesLive, [user: user]},
          {Bonfire.Tag.Web.WidgetTagsLive, []},
          {Bonfire.UI.Me.WidgetAdminsLive, []}
        ]
      ],
      users: [
        secondary: [
          pandora_public_lists_widget_enabled &&
            {Bonfire.PanDoRa.Web.WidgetPublicListsLive,
             [type: Surface.LiveComponent, id: "pandora-user-public-lists", user: user]},
          recent_publication_widget_enabled &&
            {Bonfire.OpenScience.RecentPublicationLive,  [type: Surface.LiveComponent, id: "osn-recent-publication", user: user]},
          most_cited_publication_widget_enabled &&
            {Bonfire.OpenScience.MostCitedPublicationLive, [type: Surface.LiveComponent, id: "osn-most-cited-publication", user: user]},
          author_topics_widget_enabled &&
            {Bonfire.OpenScience.AuthorTopicsLive, [type: Surface.LiveComponent, id: "osn-author-topics", user: user]},
          publication_types_widget_enabled &&
            {Bonfire.OpenScience.PublicationTypesLive, [type: Surface.LiveComponent, id: "osn-publication-types", user: user]},
          weather_widget_enabled &&
            {Bonfire.Geolocate.WidgetForecastLive, [location: e(user, :profile, :location, nil)]},
          {Bonfire.Tag.Web.WidgetTagsLive, []},
          {Bonfire.UI.Me.WidgetAdminsLive, []}
        ]
      ]
    ]

    [
      page_title: title,
      user: user,
      canonical_url: canonical_url(user, preload_if_needed: false),
      name: name,
      follows_me: follows_me,
      no_index:
        Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], false,
          current_user: user
        ),
      sidebar_widgets: sidebar_widgets
    ]
    |> debug()
  end

  def maybe_assign_aliases(socket, user) do
    socket
    |> update(
      :aliases,
      fn
        nil ->
          if(user,
            do:
              Utils.maybe_apply(
                Bonfire.Social.Graph.Aliases,
                :list_aliases,
                [user],
                fallback_return: []
              )
              |> debug("list_aliases")
              |> e(:edges, []),
            else: []
          )

        aliases ->
          aliases
      end
    )
  end

  def set_image_setting(:icon, scope, uploaded_media, settings_key, socket) do
    url = Bonfire.Files.IconUploader.remote_url(uploaded_media)

    with {:ok, settings} <-
           Bonfire.Common.Settings.put(
             settings_key,
             url,
             scope: scope,
             socket: socket
           ) do
      {
        :noreply,
        socket
        |> assign_flash(:info, l("Icon changed!"))
        |> assign(src: url)
        |> maybe_assign_context(settings)
        #  |> redirect_to(~p"/about")
      }
    end
  end

  def set_image_setting(:banner, scope, uploaded_media, settings_key, socket) do
    url = Bonfire.Files.BannerUploader.remote_url(uploaded_media)

    with {:ok, settings} <-
           Bonfire.Common.Settings.put(
             settings_key,
             url,
             scope: scope,
             socket: socket
           ) do
      {
        :noreply,
        socket
        |> assign_flash(:info, l("Image changed!"))
        |> assign(src: url)
        |> maybe_assign_context(settings)
        #  |> redirect_to(~p"/about")
      }
    end
  end
end
