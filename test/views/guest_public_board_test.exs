defmodule Bonfire.Web.Views.GuestPublicBoardTest do
  use Bonfire.UI.Me.ConnCase, async: false

  # the guest tests check the static render (`get_conn_render`), which is the page a guest gets as they have no LiveView socket; they were `conn() |> visit(path)`, which connects a LiveView on these pages. The signed-in tests keep `visit`

  alias Bonfire.UI.Common.GuestBoardLive
  # doctest Bonfire.UI.Me.HomeHeroLive

  alias Bonfire.Social.Pins
  alias Bonfire.Posts

  setup do
    # both loaders are cached for hours: start every test from the current DB state
    Bonfire.Me.Users.list_declared_moderators(cache: :reset)
    Pins.list_spotlight_activities(cache: :reset)
    Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)
    :ok
  end

  describe "guest home" do
    test "renders the public board shell with real navigation" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        false
      end)

      conn()
      |> get_conn_render("/")
      |> assert_has("#guest-board #guest-board-home", text: GuestBoardLive.instance_name())
      |> assert_has("#guest-board-icon[aria-hidden=true] img")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "Explore")
      |> assert_has("#guest-board-nav a[href='/about']", text: "About")
      |> assert_has("#guest-board-nav a[href='/conduct']", text: "Code of conduct")
      # desktop-only actions (`max-lg:hidden`): on mobile the dock carries them
      |> assert_has(".max-lg\\:hidden #guest-board-signin[href='/login']", text: "Sign in")
      |> assert_has(".max-lg\\:hidden #guest-board-signup[href='/signup']", text: "Sign up")
      # one sheet like About: the shared introduction (name as the page heading, tagline, the primary action), then the moderators above the facts at a glance
      |> assert_has("#guest-home h1#about-title", text: GuestBoardLive.instance_name())
      |> assert_has("#guest-home #about-tagline")
      |> assert_has("#guest-home #hero-signup[href='/signup']", text: "Join the community")
      |> assert_has("#guest-home #hero-login[href='/login']", text: "Sign in")
      |> assert_has("#guest-home #community-glance #about-guest-info",
        text: "Public posts readable without an account"
      )
      # no breadcrumb
      |> refute_has("#guest-board-home", text: "Public activity")
      |> refute_has("#guest-board a", text: "About this community")
      |> assert_has("#feed_heading", text: "Recent activity")
      |> assert_has("#guest-board-footer a[href='/privacy']", text: "Privacy")
      # the board owns its chrome (no widgets sidebar), but keeps the guest mobile dock: logo only, plus the actions
      |> refute_has("[data-id=right_nav_and_widgets]")
      |> assert_has("#dock-instance-home img")
      |> refute_has("#dock-instance-home", text: GuestBoardLive.instance_name())
      |> assert_has("#dock-login-action[href='/login']", text: "Sign in")
    end

    test "only links People when the directory is visible to guests" do
      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :users)

      conn()
      |> get_conn_render("/")
      |> refute_has("#guest-board-nav a[href='/users']")

      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

      conn()
      |> get_conn_render("/")
      |> assert_has("#guest-board-nav a[href='/users']", text: "People")
    end

    test "hides Spotlight entirely when nothing is pinned" do
      conn()
      |> get_conn_render("/")
      |> refute_has("[data-widget-id=instance_pinned] aside")
      |> refute_has("[data-role=widget-empty-state]")
    end

    test "shows public instance pins in Spotlight, without arrows for a single item" do
      admin = fake_admin!(fake_account!())
      post = publish!(admin, "a public post in the guest spotlight")
      Pins.pin(admin, post, :instance)
      Pins.list_spotlight_activities(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=instance_pinned] [data-role=widget-heading]",
        text: "Spotlight"
      )
      |> assert_has("[data-widget-id=instance_pinned] [data-role=pinned_card]",
        text: "a public post in the guest spotlight"
      )
      |> refute_has("[data-widget-id=instance_pinned] [data-carousel-scroll]")
    end

    test "shows static-friendly previous/next controls with several pins" do
      admin = fake_admin!(fake_account!())

      for body <- ["first guest spotlight pin", "second guest spotlight pin"] do
        Pins.pin(admin, publish!(admin, body), :instance)
      end

      Pins.list_spotlight_activities(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has(
        "[data-widget-id=instance_pinned] button[data-carousel-scroll=previous][aria-controls=instance_pinned_widget-track]"
      )
      |> assert_has(
        "[data-widget-id=instance_pinned] button[data-carousel-scroll=next][aria-controls=instance_pinned_widget-track]"
      )
      # no LiveView-only JS command, which would be mis-routed on the static guest page
      |> refute_has("[data-widget-id=instance_pinned] [data-carousel-scroll][phx-click]")
    end

    test "hides Spotlight when the instance turns it off" do
      admin = fake_admin!(fake_account!())
      Pins.pin(admin, publish!(admin, "pinned but spotlight disabled"), :instance)
      Pins.list_spotlight_activities(cache: :reset)

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :instance_pinned], false)

      conn()
      |> get_conn_render("/")
      |> refute_has("[data-widget-id=instance_pinned]")
      # the post itself is public, so it may still appear in Recent activity
      |> refute_has("[data-role=pinned_card]")
    end
  end

  describe "guest home groups" do
    test "shows local groups guests can see, but not private or federated ones" do
      creator = fake_user!(fake_account!())

      visible =
        Bonfire.Classify.Simulate.fake_group!(creator, %{
          name: "Guest visible group",
          visibility: "global"
        })

      private =
        Bonfire.Classify.Simulate.fake_group!(creator, %{
          name: "Members only group",
          visibility: "members:private"
        })

      # a public group mirrored from another instance: its `Peered` row is what makes it remote
      federated =
        Bonfire.Classify.Simulate.fake_group!(creator, %{
          name: "Federated group",
          visibility: "global"
        })

      assert {:ok, _} =
               Bonfire.Federate.ActivityPub.Peered.save_canonical_uri(
                 federated,
                 "https://elsewhere.example/groups/federated"
               )

      Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=groups] [data-role=widget-heading]", text: "Groups")
      # the compact card, with the /groups row's join action
      |> assert_has("[data-widget-id=groups] article#group-preview-#{id(visible)}",
        text: "Guest visible group"
      )
      |> assert_has(
        "[data-widget-id=groups] #group-preview-#{id(visible)} a#group-preview-link-#{id(visible)}[href='/group/#{visible.character.username}']",
        text: "Guest visible group"
      )
      |> assert_has(
        "[data-widget-id=groups] #group-preview-#{id(visible)} [data-role=group-card-action]"
      )
      |> assert_has("[data-widget-id=groups] [data-role=group-card-compact]")
      |> refute_has("[data-widget-id=groups] #group-preview-#{id(private)}")
      |> refute_has("[data-widget-id=groups]", text: "Members only group")
      |> refute_has("[data-widget-id=groups] #group-preview-#{id(federated)}")
      |> refute_has("[data-widget-id=groups]", text: "Federated group")
      |> assert_has("[data-widget-id=groups] a[href='/groups']", text: "Browse all groups")
    end

    test "the groups are the shared carousel, with dots" do
      creator = fake_user!(fake_account!())

      for name <- ["First guest group", "Second guest group"] do
        Bonfire.Classify.Simulate.fake_group!(creator, %{
          name: name,
          membership: "open",
          visibility: "global"
        })
      end

      Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=groups] [data-carousel-card] article[id^=group-preview-]",
        text: "First guest group"
      )
      |> assert_has("[data-widget-id=groups] [data-role=carousel_dots]")
    end

    test "hides the groups section when the instance turns it off" do
      creator = fake_user!(fake_account!())

      Bonfire.Classify.Simulate.fake_group!(creator, %{
        name: "Group while disabled",
        visibility: "global"
      })

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :groups], false)

      conn()
      |> get_conn_render("/")
      |> refute_has("[data-widget-id=groups]")
    end
  end

  describe "guest home community sections" do
    # part of the hero introduction; moved here from About, which no longer lists them for guests
    test "shows described resource cards separately from account actions" do
      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"About Bonfire", "https://bonfirenetworks.org/"},
        {"Community handbook", "https://example.org/handbook"}
      ])

      conn()
      |> get_conn_render("/")
      # full-width buttons labelled as configured, the host only as a tooltip (no guessed descriptions)
      |> assert_has(
        "#guest-home #community-links a[href='https://bonfirenetworks.org/'][target='_blank'][rel=noopener]",
        text: "About Bonfire"
      )
      |> assert_has(
        "#community-links a[href='https://example.org/handbook'][title='example.org']",
        text: "Community handbook"
      )
      |> refute_has("#community-links", text: "Discover the platform behind this community")
    end

    test "hides resource cards when no community links are configured" do
      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [])

      conn()
      |> get_conn_render("/")
      |> refute_has("#community-links")
    end

    test "lists public admins linking to their profiles" do
      admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has(
        "#guest-home #mods a[data-role=mod-link][href='/@#{admin.character.username}'][title='@#{admin.character.username}']",
        text: admin.profile.name
      )
    end

    test "lists the moderators and not the admins, once the instance has a moderator" do
      admin = fake_admin!(fake_account!())
      moderator = Bonfire.Me.Fake.instance_moderator!(fake_user!(fake_account!()))
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn()
      |> get_conn_render("/")
      # prove the positive first: the moderator is listed
      |> assert_has(
        "#guest-home #mods a[data-role=mod-link][href='/@#{moderator.character.username}']"
      )
      |> refute_has("#mods a[href='/@#{admin.character.username}']")
      |> assert_has("#mods [data-role=widget-heading]", text: "Moderators")
    end

    test "a moderator made after the list was first shown appears without refreshing the list" do
      _admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      # the list is cached from here on
      conn() |> get_conn_render("/") |> assert_has("#mods")

      moderator = fake_user!(fake_account!())
      assert {:ok, _} = Bonfire.Me.Users.make_moderator(moderator, skip_boundary_check: true)

      conn()
      |> get_conn_render("/")
      |> assert_has("#mods a[href='/@#{moderator.character.username}']")
    end

    test "lists every admin, however many there are" do
      admins = for _ <- 1..4, do: fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)
      count = length(Bonfire.Me.Users.list_declared_moderators())
      assert count >= 4

      session =
        conn()
        |> get_conn_render("/")
        # each admin is a card, so none are collapsed
        |> assert_has("#mods a[data-role=mod-link]", count: count)
        |> refute_has("#mods-more")

      for admin <- admins do
        assert_has(session, "#mods a[href='/@#{admin.character.username}']")
      end
    end

    test "hides the admins section when admins are hidden from guests" do
      _admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      Process.put([:bonfire_ui_me, Bonfire.UI.Me.WidgetUsersLive, :show_guests], false)

      conn()
      |> get_conn_render("/")
      |> refute_has("#mods")
    end

    test "an admin choosing to show them only to signed-in people hides them from guests" do
      account = fake_account!()
      admin = fake_admin!(account)
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      # instance settings are mirrored into the global Application env, which the sandbox doesn't roll back
      on_exit(fn ->
        Bonfire.Common.Config.delete([Bonfire.Me.Users, :show_moderators_to], :bonfire_me)
      end)

      conn()
      |> get_conn_render("/")
      |> assert_has("#mods")

      {:ok, view, _html} =
        live(conn(user: admin, account: account), "/settings/instance/configuration")

      view
      |> form("form[data-scope=instance_general]", %{
        "Elixir.Bonfire.Me.Users" => %{"show_moderators_to" => "users"}
      })
      |> render_change()

      assert Bonfire.Common.Config.get([Bonfire.Me.Users, :show_moderators_to], nil) in [
               :users,
               "users"
             ],
             "the form saves the choice as the instance's setting"

      refute Bonfire.Me.Users.moderators_visible?(nil), "the context reads it for visitors"

      conn()
      |> get_conn_render("/")
      |> refute_has("#mods")

      conn()
      |> get_conn_render("/about")
      |> refute_has("#mods")
    end

    test "the homepage shows recent activity unless the instance turns it off" do
      conn()
      |> get_conn_render("/")
      |> assert_has("#feed_heading", text: "Recent activity")

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :feed], false)

      conn()
      |> get_conn_render("/")
      |> refute_has("#feed_heading")
    end

    test "the introduction is the homepage's first widget, and an admin can turn it off" do
      first_widget =
        conn()
        |> get("/")
        |> html_response(200)
        |> Floki.parse_document!()
        |> Floki.find("#home_main_widgets [data-widget-id]")
        |> Enum.flat_map(&Floki.attribute(&1, "data-widget-id"))
        |> List.first()

      assert first_widget == "intro"

      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=intro] #about-tagline")

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :intro], false)

      conn()
      |> get_conn_render("/")
      |> refute_has("#about-tagline")
    end

    test "the instance facts are one of the homepage's widgets" do
      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=instance_facts] [data-role=widget-body] #about-meta")
    end

    test "the community links are one of the homepage's widgets" do
      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"Community handbook", "https://example.org/handbook"}
      ])

      conn()
      |> get_conn_render("/")
      |> assert_has(
        "[data-widget-id=community_links] #community-links a[href='https://example.org/handbook']"
      )
    end

    test "the community rules are one of the homepage's widgets" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        [%{sections: [%{rules: [%{name: "Be kind"}, %{name: "No spam"}]}]}]
      end)

      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=community_rules]", text: "Be kind")
    end

    test "an instance that shows its moderators only to signed-in people shows them to no visitor, anywhere" do
      # the instance status widget lists the moderators too
      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets],
        main: [:mods, :instance_status]
      )

      # the page seen before there is any moderator, so a widget keeping its own copy of the list would go on showing none
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)
      conn() |> get_conn_render("/")

      _admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has("#mods")
      |> assert_has("[data-widget-id=instance_status]", text: "Moderators")

      Process.put([:bonfire_me, Bonfire.Me.Users, :show_moderators_to], :users)

      conn()
      |> get_conn_render("/")
      |> refute_has("#mods")
      |> refute_has("[data-widget-id=instance_status]", text: "Moderators")

      conn()
      |> get_conn_render("/about")
      |> refute_has("#mods")
    end

    test "an instance that shows its moderators to nobody hides them from signed-in people too" do
      _admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)
      account = fake_account!()
      me = fake_user!(account)

      conn(user: me, account: account)
      |> visit("/about")
      |> assert_has("#mods")

      Process.put([:bonfire_me, Bonfire.Me.Users, :show_moderators_to], :nobody)

      conn(user: me, account: account)
      |> visit("/about")
      |> refute_has("#mods")
    end

    test "the moderators are one of the homepage's widgets" do
      _admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn()
      |> get_conn_render("/")
      |> assert_has("[data-widget-id=mods] #mods a[data-role=mod-link]")
    end

    test "widgets the instance puts on the homepage show for visitors" do
      # Config.get reads these per test process
      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets], main: [:custom_text])

      Process.put([:bonfire_ui_common, Bonfire.UI.Common.Widgets, :custom], %{
        text: %{title: "Start here", text: "Hello **visitors**"}
      })

      conn()
      |> get_conn_render("/")
      |> assert_has("#home_main_widgets", text: "Start here")
      |> assert_has("#home_main_widgets strong", text: "visitors")
    end

    test "an admin's welcome text shows on the guest home as markdown, with headings, links and images" do
      account = fake_account!()
      admin = fake_admin!(account)
      keys = [:ui, :theme, :instance_welcome, :description]

      # instance settings are mirrored into the global Application env, which the sandbox doesn't roll back
      on_exit(fn ->
        if Bonfire.Common.Config.get(keys, nil) do
          [otp_app | keys] = Bonfire.Common.Config.keys_tree(keys)
          Bonfire.Common.Config.delete(keys, otp_app)
        end
      end)

      {:ok, view, _html} = live(conn(user: admin, account: account), "/settings/instance/about")

      view
      |> form("form[data-scope=instance_welcome_description]", %{
        "ui" => %{
          "theme" => %{
            "instance_welcome" => %{
              "description" =>
                "## Start here\n\nRead [the guide](https://welcome.example.local/guide).\n\n![Our hall](https://welcome.example.local/hall.png)"
            }
          }
        }
      })
      |> render_submit()

      conn()
      |> get_conn_render("/")
      |> assert_has("#about-description h2", text: "Start here")
      |> assert_has("#about-description a[href='https://welcome.example.local/guide']",
        text: "the guide"
      )
      |> assert_has("#about-description img[src='https://welcome.example.local/hall.png']")
    end

    test "are listed on the guest About page, without the community links" do
      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"Community handbook", "https://example.org/handbook"}
      ])

      admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn()
      |> get_conn_render("/about")
      |> refute_has("#community-links")
      |> assert_has(
        "#mods a[data-role=mod-link][href='/@#{admin.character.username}']",
        text: admin.profile.name
      )
    end

    test "stay off the guest About page when hidden from guests" do
      _admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      Process.put([:bonfire_ui_me, Bonfire.UI.Me.WidgetUsersLive, :show_guests], false)

      conn()
      |> get_conn_render("/about")
      |> refute_has("#mods")
    end
  end

  describe "guest about" do
    test "renders the board with the tagline, current nav and participation" do
      conn()
      |> get_conn_render("/about")
      |> assert_has("#guest-board")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "About")
      # About is a single sheet on the board's canvas, not a stack of cards
      |> assert_has("#guest-board[data-page=about] article#about-page")
      |> assert_has("#guest-board article#about-page", count: 1)
      # the community's name is the page heading, with the tagline under it
      |> assert_has("#guest-board h1#about-title", text: GuestBoardLive.instance_name())
      |> assert_has("#guest-board #about-tagline")
      |> refute_has("#participate")
      # what a guest can do without an account sits in the meta line under the tagline
      |> assert_has("#community-glance #about-meta #about-guest-info",
        text: "Public posts readable without an account"
      )
      |> refute_has("#guest-board a[href='#participate']")
      |> refute_has("#about-guest-info a[href='/login']")
    end

    test "keeps account creation in navigation when signups are open" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        false
      end)

      conn()
      |> get_conn_render("/about")
      |> refute_has("#about-signup")
      |> refute_has("#about-meta [data-role=signup-closed-note]")
      |> assert_has("#guest-board-signin", text: "Sign in")
      |> assert_has("#guest-board-signup[href='/signup']", text: "Sign up")
      |> assert_has("#dock-signup-action")
    end

    test "does not offer account creation on invite-only instances" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        true
      end)

      conn()
      |> get_conn_render("/about")
      |> refute_has("#about-signup")
      |> assert_has("#about-meta [data-role=signup-closed-note]",
        text: "by invitation only"
      )
      |> assert_has("#guest-board-signin[href='/login']", text: "Sign in")
      |> refute_has("#guest-board-signup")
      |> refute_has("#dock-signup-action")
      |> assert_has("#dock-login-action", text: "Sign in")
    end

    test "an instance that takes sign-ups from certain email domains does not say it is by invitation only" do
      # the instance is not invite-only: people with an eligible address can sign up, so the note names the real rule
      Repatch.patch(Bonfire.Me.Accounts, :signup_credentials_active?, [mode: :shared], fn ->
        true
      end)

      conn()
      |> get_conn_render("/about")
      |> assert_has("#about-meta [data-role=signup-closed-note]",
        text: "limited to certain email domains or sign-in services"
      )
      |> refute_has("#about-meta [data-role=signup-closed-note]", text: "by invitation only")
    end

    # new accounts are created on another site (an external sign-up page, as with Ghost)
    defp with_external_signup_page do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        true
      end)

      Repatch.patch(Bonfire.UI.Me.LoginLive, :external_signup_url, [mode: :shared], fn ->
        "https://jacobin.de/join"
      end)

      # a contact is set too: the sign-up page wins, since that is where an account comes from
      Process.put(
        [:bonfire, :ui, :theme, :instance_welcome, :invite_contact_email],
        "invites@example.org"
      )
    end

    test "with an external sign-up page, the About note says where and links there" do
      with_external_signup_page()

      conn()
      |> get_conn_render("/about")
      |> assert_has(
        "#about-meta [data-role=signup-closed-note] a[href='https://jacobin.de/join']",
        text: "New accounts are created on jacobin.de"
      )
      |> refute_has("#about-meta [data-role=signup-closed-note]", text: "by invitation only")
    end

    test "with an external sign-up page, the About button is a sign-up link to it, not a request for an invite" do
      with_external_signup_page()

      conn()
      |> get_conn_render("/about")
      |> assert_has("#about-page #about-request-invite[href='https://jacobin.de/join']",
        text: "Sign up"
      )
      |> refute_has("#about-page a[href^='mailto:']")
      |> refute_has("#about-page #about-request-invite", text: "Request an invite")
    end

    test "with an external sign-up page, the guest Home button is the same sign-up link" do
      with_external_signup_page()

      conn()
      |> get_conn_render("/")
      |> assert_has("#home-hero-actions #about-request-invite[href='https://jacobin.de/join']",
        text: "Sign up"
      )
      |> refute_has("#home-hero-actions a[href^='mailto:']")
    end

    # an instance that doesn't federate can't be messaged from another one, so the guest is left with the sign-up link
    test "with an external sign-up page and federation off, the About buttons are only the sign-up link" do
      with_external_signup_page()
      Process.put(:federating, false)

      conn()
      |> get_conn_render("/about")
      |> assert_has("#about-page #about-request-invite[href='https://jacobin.de/join']",
        text: "Sign up"
      )
      |> refute_has("#about-page a", text: "Message the moderators")
    end

    test "keeps an invitation action in the introduction when a contact is configured" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        true
      end)

      Process.put(
        [:bonfire, :ui, :theme, :instance_welcome, :invite_contact_email],
        "invites@example.org"
      )

      conn()
      |> get_conn_render("/about")
      |> refute_has("#participate")
      |> assert_has("#about-meta [data-role=signup-closed-note]",
        text: "by invitation only"
      )
      # the button writes to the contact itself, instead of sending the visitor on to another "Request an invite"
      |> assert_has("#about-page #about-request-invite[href^='mailto:invites@example.org']",
        text: "Request an invite"
      )
      # beside it, for someone on another server: the "interact from your instance" form with the moderators filled in
      |> assert_has("#about-page header a[href^='/remote_interaction?type=message']",
        text: "Message the moderators"
      )
    end

    test "the guest Home offers the same invitation action when a contact is configured" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        true
      end)

      Process.put(
        [:bonfire, :ui, :theme, :instance_welcome, :invite_contact_email],
        "invites@example.org"
      )

      conn()
      |> get_conn_render("/")
      |> assert_has(
        "#home-hero-actions #about-request-invite[href^='mailto:invites@example.org']",
        text: "Request an invite"
      )
      |> assert_has("#home-hero-actions a[href^='/remote_interaction?type=message']",
        text: "Message the moderators"
      )
    end

    test "with no contact configured there is no invitation mail link, but moderators can still be messaged" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        true
      end)

      conn()
      |> get_conn_render("/about")
      |> refute_has("#about-request-invite")
      |> assert_has("#about-page header a[href^='/remote_interaction?type=message']",
        text: "Message the moderators"
      )
    end

    test "shows a short rules list without the Show all toggle or its checkbox" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        [%{sections: [%{rules: [%{name: "Be kind"}, %{name: "No spam"}]}]}]
      end)

      conn()
      |> get_conn_render("/about")
      |> assert_has("#community-rules li", text: "Be kind")
      # an unlabelled checkbox would still be reachable with the keyboard
      |> refute_has("#community-rules-all")
      |> refute_has("#community-rules [data-role=show-all]")
    end

    test "hides the rules section when no rules are selected" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        []
      end)

      conn()
      |> get_conn_render("/about")
      |> refute_has("#community-rules")
    end
  end

  describe "guest code of conduct" do
    test "renders the board with the conduct text and current nav" do
      Process.put([:bonfire, :terms, :conduct], "Be **kind** to each other.")

      conn()
      |> get_conn_render("/conduct")
      |> assert_has("#guest-board #guest-board-sheet h1[data-role=page-title]",
        text: "Code of conduct"
      )
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "Code of conduct")
      |> assert_has("#conduct-body strong", text: "kind")
      |> refute_has("[data-id=right_nav_and_widgets]")
    end
  end

  describe "guest privacy policy and impressum" do
    test "render in the board's sheet, reached from its footer" do
      Process.put([:bonfire, :terms, :privacy], "We keep **as little** as we can.")

      conn()
      |> get_conn_render("/privacy")
      |> assert_has("#guest-board #guest-board-sheet h1[data-role=page-title]",
        text: "Privacy policy"
      )
      |> assert_has("#privacy-body strong", text: "as little")
      |> assert_has("#guest-board-footer a[href='/privacy']", text: "Privacy")
      # not a tab, so no tab is marked current
      |> refute_has("#guest-board-nav a[aria-current=page]")
      |> refute_has("[data-id=right_nav_and_widgets]")
    end

    test "privacy points to the Bonfire project's policy when none is configured" do
      Process.put([:bonfire, :terms, :privacy], "")

      conn()
      |> get_conn_render("/privacy")
      |> assert_has("#privacy-body a[href='https://bonfirenetworks.org/privacy']")
    end

    test "impressum shows its text and the community links" do
      Process.put([:bonfire, :terms, :impressum], "Run by **Example Collective**.")

      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"Community handbook", "https://example.org/handbook"}
      ])

      conn()
      |> get_conn_render("/impressum")
      |> assert_has("#guest-board #guest-board-sheet h1[data-role=page-title]", text: "Impressum")
      |> assert_has("#impressum-body strong", text: "Example Collective")
      |> assert_has("#guest-board-sheet #community-links a[href='https://example.org/handbook']",
        text: "Community handbook"
      )
      |> assert_has("#guest-board-footer a[href='/impressum']")
    end
  end

  describe "auth pages" do
    test "log in sits in the board's form sheet, without the tabs and with only Sign up in the masthead" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        false
      end)

      conn()
      |> get_conn_render("/login")
      |> assert_has("#guest-board #login h1[data-role=page-title]", text: "Sign in")
      |> assert_has("#login #login-form")
      |> refute_has("#guest-board-nav")
      # the form's button is the page's action, so the masthead only offers the other route
      |> refute_has("#guest-board-signin")
      |> assert_has("#guest-board-signup[href='/signup']", text: "Sign up")
      |> assert_has("#guest-board-footer a[href='/privacy']")
    end

    test "sign up only offers Log in in the masthead" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        false
      end)

      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        []
      end)

      conn()
      |> get_conn_render("/signup")
      |> assert_has("#guest-board #signup h1[data-role=page-title]", text: "Sign up")
      |> assert_has("#guest-board-signin[href='/login']")
      |> refute_has("#guest-board-signup")
    end

    test "sign up without community rules shows just the form" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        []
      end)

      conn()
      |> get_conn_render("/signup")
      |> assert_has("#signup #signup-form")
      |> refute_has("#signup #community-rules")
    end

    test "sign up lists the community rules above the form, as on About" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        [
          %{
            sections: [
              %{rules: for(name <- ~w(One Two Three Four Five Six Seven), do: %{name: name})}
            ]
          }
        ]
      end)

      conn()
      |> get_conn_render("/signup")
      |> assert_has("#signup #community-rules h2", text: "Community rules")
      |> assert_has("#signup #community-rules li", text: "Seven")
      |> assert_has("#signup #community-rules [data-role=show-all]", text: "Show all 7 rules")
      |> assert_has("#signup #community-rules a[href='/conduct']",
        text: "Read the full code of conduct"
      )
      |> assert_has("#signup #signup-form label", text: "Email address")
      |> assert_has("#signup #signup-form label", text: "Choose a password")
    end

    test "forgot password heads the form sheet with its own state's title, without the tabs" do
      conn()
      |> get_conn_render("/login/forgot-password")
      |> assert_has("#guest-board #forgot-password h1[data-role=page-title]")
      |> refute_has("#guest-board-nav")
      |> assert_has("#guest-board-footer a[href='/privacy']")
    end

    test "a signed-in account changing its password gets the masthead without tabs or actions" do
      account = fake_account!()
      user = fake_user!(account)

      conn(user: user, account: account)
      |> visit("/account/password/change")
      |> assert_has("#guest-board #change-password h1[data-role=page-title]",
        text: "Change your password"
      )
      |> assert_has("#change-password-form")
      |> refute_has("#guest-board-nav")
      |> refute_has("#guest-board-signin")
      |> assert_has("#guest-board-footer")
    end
  end

  describe "guest people directory" do
    test "renders the board listing users, with People as the current nav item" do
      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)
      user = fake_user!(fake_account!())

      conn()
      |> get_conn_render("/users")
      |> assert_has("#guest-board #guest-board-sheet h1[data-role=page-title]",
        text: "Users directory"
      )
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "People")
      |> assert_has("#guest-people [data-role=person-row]", text: user.profile.name)
      |> refute_has("[data-id=right_nav_and_widgets]")
    end
  end

  describe "signed-in users" do
    setup do
      account = fake_account!()
      user = fake_user!(account)
      {:ok, conn: conn(user: user, account: account)}
    end

    test "are still redirected away from the guest home", %{conn: conn} do
      conn
      |> visit("/")
      |> refute_has("#guest-board")
      |> assert_path("/dashboard")
    end

    test "still find the admins on About, since they never see the guest home", %{conn: conn} do
      admin = fake_admin!(fake_account!())
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn
      |> visit("/about")
      |> assert_has("#member-about #mods a[data-role=mod-link]",
        text: "@#{admin.character.username}"
      )
    end

    test "share the guest About content inside the signed-in layout", %{conn: conn} do
      # the banner only shows when one is configured
      Process.put([:bonfire, :ui, :theme, :instance_image], "https://example.org/banner.png")

      conn
      |> visit("/about")
      |> refute_has("#guest-board")
      |> assert_has("#member-about [data-role=about-banner]")
      |> assert_has("#member-about h1#about-title")
      |> assert_has("#member-about #community-expectations")
      |> refute_has("#participate")
      |> refute_has("#about-signup")
    end

    test "keep the regular Privacy and Impressum layouts", %{conn: conn} do
      Process.put([:bonfire, :terms, :impressum], "Run by Example Collective.")

      conn
      |> visit("/privacy")
      |> refute_has("#guest-board")

      conn
      |> visit("/impressum")
      |> refute_has("#guest-board")
    end

    test "keep the regular Code of conduct and People layouts", %{conn: conn} do
      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :users)

      conn
      |> visit("/conduct")
      |> refute_has("#guest-board")

      conn
      |> visit("/users")
      |> refute_has("#guest-board")
      |> assert_has("[data-id=main_section]")
    end
  end

  defp publish!(user, body) do
    {:ok, post} =
      Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: body}},
        boundary: "public"
      )

    post
  end
end
