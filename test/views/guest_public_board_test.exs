defmodule Bonfire.Web.Views.GuestPublicBoardTest do
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.UI.Common.GuestBoardLive
  alias Bonfire.Social.Pins
  alias Bonfire.Posts

  setup do
    # both loaders are cached for hours: start every test from the current DB state
    Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)
    Bonfire.UI.Reactions.InstancePins.list_activities(cache: :reset)
    Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)
    :ok
  end

  describe "guest home" do
    test "renders the public board shell with real navigation" do
      conn()
      |> visit("/")
      |> assert_has("#guest-board #guest-board-home", text: GuestBoardLive.instance_name())
      |> assert_has("#guest-board-home [aria-hidden=true] img")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "Explore")
      |> assert_has("#guest-board-nav a[href='/about']", text: "About")
      |> assert_has("#guest-board-nav a[href='/conduct']", text: "Code of conduct")
      |> assert_has("#guest-board-signin[href='/login']", text: "Sign in")
      |> assert_has("h1", text: GuestBoardLive.instance_name())
      # the instance identity lives in the header only: no breadcrumb, no intro block
      |> refute_has("#guest-board-home", text: "Public activity")
      |> refute_has("#guest-board a", text: "About this community")
      |> assert_has("#guest-feed-title", text: "Recent activity")
      |> assert_has("#guest-board-footer a[href='/privacy']", text: "Privacy")
      # the board owns all chrome: no widgets sidebar and no guest mobile dock
      |> refute_has("[data-id=right_nav_and_widgets]")
      |> refute_has("#dock-login-action")
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
      Bonfire.UI.Reactions.InstancePins.list_activities(cache: :reset)

      conn()
      |> visit("/")
      |> assert_has("#guest-spotlight [data-role=widget-heading]", text: "Spotlight")
      |> assert_has("#guest-spotlight [data-role=widget-subtitle]", text: "Pinned by the community")
      |> assert_has("#guest-spotlight .spotlight_clamp",
        text: "a public post in the guest spotlight"
      )
      |> refute_has("#guest-spotlight [data-carousel-scroll]")
    end

    test "shows static-friendly previous/next controls with several pins" do
      admin = fake_admin!(fake_account!())

      for body <- ["first guest spotlight pin", "second guest spotlight pin"] do
        Pins.pin(admin, publish!(admin, body), :instance)
      end

      Bonfire.UI.Reactions.InstancePins.list_activities(cache: :reset)

      conn()
      |> visit("/")
      |> assert_has(
        "#guest-spotlight button[data-carousel-scroll=previous][aria-controls=pinned-carousel]"
      )
      |> assert_has(
        "#guest-spotlight button[data-carousel-scroll=next][aria-controls=pinned-carousel]"
      )
      # no LiveView-only JS command, which would be mis-routed on the static guest page
      |> refute_has("#guest-spotlight [data-carousel-scroll][phx-click]")
    end

    test "hides Spotlight when the instance turns it off" do
      admin = fake_admin!(fake_account!())
      Pins.pin(admin, publish!(admin, "pinned but spotlight disabled"), :instance)
      Bonfire.UI.Reactions.InstancePins.list_activities(cache: :reset)

      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :include, :instance_pinned], false)

      conn()
      |> visit("/")
      |> refute_has("#guest-spotlight")
      # the post itself is public, so it may still appear in Recent activity
      |> refute_has(".spotlight_clamp")
    end
  end

  describe "guest home groups" do
    test "shows groups guests can see, but not private ones" do
      creator = fake_user!(fake_account!())

      Bonfire.Classify.Simulate.fake_group!(creator, %{
        name: "Guest visible group",
        visibility: "global"
      })

      Bonfire.Classify.Simulate.fake_group!(creator, %{
        name: "Members only group",
        visibility: "members:private"
      })

      Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)

      conn()
      |> visit("/")
      |> assert_has("#guest-groups [data-role=widget-heading]", text: "Groups")
      |> assert_has("#guest-groups [data-role=group-card-compact]", text: "Guest visible group")
      # compact card: no cover image block
      |> refute_has("#guest-groups [data-role=group-card-cover]")
      |> refute_has("#guest-groups", text: "Members only group")
      |> assert_has("#guest-groups a[href='/groups']", text: "Browse all groups")
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

  describe "guest about" do
    test "renders the board with the tagline, current nav and participation" do
      conn()
      |> visit("/about")
      |> assert_has("#guest-board")
      |> assert_has("#guest-board-nav a[aria-current=page]", text: "About")
      |> assert_has("[data-role=about-eyebrow]", text: "About #{GuestBoardLive.instance_name()}")
      |> assert_has("#about-tagline")
      |> assert_has("#participate h2", text: "Taking part")
      |> refute_has("#guest-board a[href='#participate']")
      |> assert_has("#participate a[href='/login']", text: "Already a member? Sign in")
    end

    test "offers account creation when signups are open" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn -> false end)

      conn()
      |> visit("/about")
      |> assert_has("#about-signup", text: "Create an account")
      |> refute_has("#participate [data-role=signup-closed-note]")
    end

    test "does not offer account creation on invite-only instances" do
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, [mode: :shared], fn -> true end)

      conn()
      |> visit("/about")
      |> refute_has("#about-signup")
      |> assert_has("#participate [data-role=signup-closed-note]", text: "by invitation only")
    end

    test "lists public admins linking to their profiles" do
      admin = fake_admin!(fake_account!())
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

      conn()
      |> visit("/about")
      |> assert_has("#community-admins a[data-role=admin-link][href='/@#{admin.character.username}']",
        text: "@#{admin.character.username}"
      )
    end

    test "hides the admins section when admins are hidden from guests" do
      _admin = fake_admin!(fake_account!())
      Bonfire.UI.Me.WidgetUsersLive.list_admins(cache: :reset)

      Process.put([:bonfire_ui_me, Bonfire.UI.Me.WidgetAdminsLive, :show_guests], false)

      conn()
      |> visit("/about")
      |> refute_has("#community-admins")
    end

    test "hides the rules section when no rules are selected" do
      Repatch.patch(Bonfire.CommunityRules, :get_instance_rules_sections, [mode: :shared], fn -> [] end)

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

    test "share the guest About content inside the signed-in layout", %{conn: conn} do
      conn
      |> visit("/about")
      |> refute_has("#guest-board")
      |> assert_has("#member-about [data-role=about-banner]")
      |> assert_has("#member-about [data-role=about-eyebrow]")
      |> assert_has("#member-about #about-tagline")
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
