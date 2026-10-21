defmodule Bonfire.Web.Views.GuestPublicBoardTest do
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.UI.Common.GuestBoardLive
  # doctest Bonfire.Web.Components.HomeHeroLive

  alias Bonfire.Social.Pins
  alias Bonfire.Posts

  setup do
    # both loaders are cached for hours: start every test from the current DB state
    Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)
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
      |> visit("/")
      |> assert_has("#guest-board #guest-board-home", text: GuestBoardLive.instance_name())
      |> assert_has("#guest-board-icon[aria-hidden=true] img")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "Explore")
      |> assert_has("#guest-board-nav a[href='/about']", text: "About")
      |> assert_has("#guest-board-nav a[href='/conduct']", text: "Code of conduct")
      # desktop-only actions (`max-lg:hidden`): on mobile the dock carries them
      |> assert_has(".max-lg\\:hidden #guest-board-signin[href='/login']", text: "Log in")
      |> assert_has(".max-lg\\:hidden #guest-board-signup[href='/signup']", text: "Sign up")
      # profile-style intro under the banner: the instance name is the page heading, then the tagline and the primary action
      |> assert_has("#guest-board-hero h1#guest-hero-name", text: GuestBoardLive.instance_name())
      |> assert_has("#guest-board-hero #about-tagline")
      |> assert_has("#guest-board-hero #hero-signup[href='/signup']", text: "Join the community")
      |> assert_has("#guest-board-hero #hero-login[href='/login']", text: "Log in")
      |> assert_has("#guest-board-hero #about-guest-info",
        text: "You can read public conversations"
      )
      # no breadcrumb
      |> refute_has("#guest-board-home", text: "Public activity")
      |> refute_has("#guest-board a", text: "About this community")
      |> assert_has("#guest-feed-title", text: "Recent activity")
      |> assert_has("#guest-board-footer a[href='/privacy']", text: "Privacy")
      # the board owns its chrome (no widgets sidebar), but keeps the guest mobile dock: logo only, plus the actions
      |> refute_has("[data-id=right_nav_and_widgets]")
      |> assert_has("#dock-instance-home img")
      |> refute_has("#dock-instance-home", text: GuestBoardLive.instance_name())
      |> assert_has("#dock-login-action[href='/login']", text: "Log in")
    end

    test "only links People when the directory is visible to guests" do
      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :users)

      conn()
      |> visit("/")
      |> refute_has("#guest-board-nav a[href='/users']")

      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

      conn()
      |> visit("/")
      |> assert_has("#guest-board-nav a[href='/users']", text: "People")
    end

    test "hides Spotlight entirely when nothing is pinned" do
      conn()
      |> visit("/")
      |> refute_has("#guest-spotlight aside")
      |> refute_has("[data-role=widget-empty-state]")
    end

    test "shows public instance pins in Spotlight, without arrows for a single item" do
      admin = fake_admin!(fake_account!())
      post = publish!(admin, "a public post in the guest spotlight")
      Pins.pin(admin, post, :instance)
      Pins.list_spotlight_activities(cache: :reset)

      conn()
      |> visit("/")
      |> assert_has("#guest-spotlight [data-role=widget-heading]", text: "Spotlight")
      |> assert_has("#guest-spotlight [data-role=pinned_card]",
        text: "a public post in the guest spotlight"
      )
      |> refute_has("#guest-spotlight [data-carousel-scroll]")
    end

    test "shows static-friendly previous/next controls with several pins" do
      admin = fake_admin!(fake_account!())

      for body <- ["first guest spotlight pin", "second guest spotlight pin"] do
        Pins.pin(admin, publish!(admin, body), :instance)
      end

      Pins.list_spotlight_activities(cache: :reset)

      conn()
      |> visit("/")
      |> assert_has(
        "#guest-spotlight button[data-carousel-scroll=previous][aria-controls=instance_pinned_widget-track]"
      )
      |> assert_has(
        "#guest-spotlight button[data-carousel-scroll=next][aria-controls=instance_pinned_widget-track]"
      )
      # no LiveView-only JS command, which would be mis-routed on the static guest page
      |> refute_has("#guest-spotlight [data-carousel-scroll][phx-click]")
    end

    test "hides Spotlight when the instance turns it off" do
      admin = fake_admin!(fake_account!())
      Pins.pin(admin, publish!(admin, "pinned but spotlight disabled"), :instance)
      Pins.list_spotlight_activities(cache: :reset)

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :instance_pinned], false)

      conn()
      |> visit("/")
      |> refute_has("#guest-spotlight")
      # the post itself is public, so it may still appear in Recent activity
      |> refute_has("[data-role=pinned_card]")
    end
  end

  describe "guest home groups" do
    test "shows local groups guests can see, but not private or federated ones" do
      creator = fake_user!(fake_account!())

      Bonfire.Classify.Simulate.fake_group!(creator, %{
        name: "Guest visible group",
        visibility: "global"
      })

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
      |> visit("/")
      |> assert_has("#guest-groups [data-role=widget-heading]", text: "Groups")
      |> assert_has("#guest-groups [data-role=group-card-compact]", text: "Guest visible group")
      # compact card: no cover image block
      |> refute_has("#guest-groups [data-role=group-card-cover]")
      |> refute_has("#guest-groups", text: "Members only group")
      |> refute_has("#guest-groups", text: "Federated group")
      |> assert_has("#guest-groups a[href='/groups']", text: "Browse all groups")
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
      |> visit("/")
      |> assert_has("#guest-groups [data-carousel-card] [data-role=group-card-compact]",
        text: "First guest group"
      )
      |> assert_has("#guest-groups [data-role=carousel_dots]")
    end

    test "hides the groups section when the instance turns it off" do
      creator = fake_user!(fake_account!())

      Bonfire.Classify.Simulate.fake_group!(creator, %{
        name: "Group while disabled",
        visibility: "global"
      })

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :groups], false)

      conn()
      |> visit("/")
      |> refute_has("#guest-groups")
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
      |> visit("/")
      # full-width buttons labelled as configured, the host only as a tooltip (no guessed descriptions)
      |> assert_has(
        "#guest-board-hero #community-links a[href='https://bonfirenetworks.org/'][target='_blank'][rel=noopener]",
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
      |> visit("/")
      |> refute_has("#community-links")
    end

    test "lists public admins linking to their profiles" do
      admin = fake_admin!(fake_account!())
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

      conn()
      |> visit("/")
      |> assert_has(
        "#guest-board-hero #community-admins a[data-role=admin-link][href='/@#{admin.character.username}'][title='@#{admin.character.username}']",
        text: admin.profile.name
      )
    end

    test "names up to two admins and collapses the rest when there are more than three" do
      admins = for _ <- 1..4, do: fake_admin!(fake_account!())
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)
      count = length(Bonfire.UI.Me.WidgetUsersLive.list_admins())
      assert count >= 4

      session =
        conn()
        |> visit("/")
        # 2 named + the rest expandable in place, so every admin is still one click away
        |> assert_has("#community-admins a[data-role=admin-link]", count: count)
        |> assert_has("#community-admins-more summary", text: "and #{count - 2} others")
        |> assert_has("#community-admins-more a[data-role=admin-link]", count: count - 2)

      for admin <- admins do
        assert_has(session, "#community-admins a[href='/@#{admin.character.username}']")
      end
    end

    test "hides the admins section when admins are hidden from guests" do
      _admin = fake_admin!(fake_account!())
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

      Process.put([:bonfire_ui_me, Bonfire.UI.Me.WidgetAdminsLive, :show_guests], false)

      conn()
      |> visit("/")
      |> refute_has("#community-admins")
    end

    test "are no longer on the guest About page" do
      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"Community handbook", "https://example.org/handbook"}
      ])

      _admin = fake_admin!(fake_account!())
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

      conn()
      |> visit("/about")
      |> refute_has("#community-links")
      |> refute_has("#community-admins")
    end
  end

  describe "guest about" do
    test "renders the board with the tagline, current nav and participation" do
      conn()
      |> visit("/about")
      |> assert_has("#guest-board")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "About")
      # the tagline is the page heading (no "About <name>" eyebrow above it since the guests UI rework)
      |> assert_has("#guest-board h1#about-tagline")
      |> refute_has("#participate")
      |> assert_has("#about-guest-info",
        text: "You can read public conversations without an account."
      )
      |> refute_has("#guest-board a[href='#participate']")
      |> refute_has("#about-guest-info a[href='/login']")
    end

    test "keeps account creation in navigation when signups are open" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        false
      end)

      conn()
      |> visit("/about")
      |> refute_has("#about-signup")
      |> refute_has("#about-guest-info [data-role=signup-closed-note]")
      |> assert_has("#guest-board-signin", text: "Log in")
      |> assert_has("#guest-board-signup[href='/signup']", text: "Sign up")
      |> assert_has("#dock-signup-action")
    end

    test "does not offer account creation on invite-only instances" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn ->
        true
      end)

      conn()
      |> visit("/about")
      |> refute_has("#about-signup")
      |> assert_has("#about-guest-info [data-role=signup-closed-note]",
        text: "by invitation only"
      )
      |> assert_has("#guest-board-signin[href='/login']", text: "Sign in")
      |> refute_has("#guest-board-signup")
      |> refute_has("#dock-signup-action")
      |> assert_has("#dock-login-action", text: "Sign in")
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
      |> visit("/about")
      |> refute_has("#participate")
      |> assert_has("#about-guest-info [data-role=signup-closed-note]",
        text: "by invitation only"
      )
      |> assert_has("#about-guest-info #about-request-invite[href='/signup']",
        text: "Request an invite"
      )
    end

    test "hides the rules section when no rules are selected" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn ->
        []
      end)

      conn()
      |> visit("/about")
      |> refute_has("#community-rules")
    end
  end

  describe "guest code of conduct" do
    test "renders the board with the conduct text and current nav" do
      Process.put([:bonfire, :terms, :conduct], "Be **kind** to each other.")

      conn()
      |> visit("/conduct")
      |> assert_has("#guest-board h1[data-role=page-title]", text: "Code of conduct")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "Code of conduct")
      |> assert_has("#conduct-body strong", text: "kind")
      |> refute_has("[data-id=right_nav_and_widgets]")
    end
  end

  describe "guest people directory" do
    test "renders the board listing users, with People as the current nav item" do
      Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)
      user = fake_user!(fake_account!())

      conn()
      |> visit("/users")
      |> assert_has("#guest-board h1[data-role=page-title]", text: "Users directory")
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
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

      conn
      |> visit("/about")
      |> assert_has("#member-about #community-admins a[data-role=admin-link]",
        text: "@#{admin.character.username}"
      )
    end

    test "share the guest About content inside the signed-in layout", %{conn: conn} do
      conn
      |> visit("/about")
      |> refute_has("#guest-board")
      |> assert_has("#member-about [data-role=about-banner]")
      |> assert_has("#member-about h1#about-tagline")
      |> assert_has("#member-about #community-expectations")
      |> refute_has("#participate")
      |> refute_has("#about-signup")
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
