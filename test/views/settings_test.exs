defmodule Bonfire.UI.Me.SettingsTest do
  use Bonfire.UI.Me.ConnCase, async: false
  use Mneme
  import Phoenix.LiveViewTest
  # alias Bonfire.Files.Simulation, as: FakeFiles

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Common.Config

  setup_all do
    orig1 = Config.get(:pagination_hard_max_limit)

    orig2 = Config.get(:default_pagination_limit)

    Config.put(:pagination_hard_max_limit, 10)

    Config.put(:default_pagination_limit, 10)

    on_exit(fn ->
      Config.put(:pagination_hard_max_limit, orig1)

      Config.put(:default_pagination_limit, orig2)
    end)
  end

  setup do
    account = fake_account!()
    alice = fake_user!(account)
    conn = conn(user: alice, account: account)
    {:ok, conn: conn, account: account, alice: alice}
  end

  describe "Appearance" do
    # test "As a user I want to select a different theme", %{conn: conn} do
    #   conn
    #   |> visit("/settings/user/preferences/appearance")
    #   |> assert_has("[data-theme=dracula]")
    #   |> click_button("[data-set-theme=dracula]", "Enable")
    #   |> assert_has("[data-theme=dracula]")

    # end

    test "As a user I want to select a different font" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"font_family" => "Luciole"}})

      # force a refresh
      {:ok, _refreshed_view, html} = live(conn, next)

      assert html =~ "fonts/luciole.css"
      # the default Inter font CSS should not be loaded after switching
      refute html =~ "fonts/inter-latin.css"
      # the CSS variable should reflect the chosen font name
      assert html =~ ~s|--font-sans: "Luciole"|
    end

    test "As a user, the chosen font is reflected in the page <head> after a fresh load" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"font_family" => "OpenDyslexic"}})

      # simulate a hard refresh with a NEW conn for the same user
      fresh_conn = conn(user: alice, account: account)
      {:ok, _view, html} = live(fresh_conn, "/dashboard")

      assert html =~ "fonts/opendyslexic.css"
      refute html =~ "fonts/inter-latin.css"
      assert html =~ ~s|--font-sans: "OpenDyslexic"|
    end

    test "Changing the font pushes a set_font event so the head updates without a refresh" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{
        "_target" => ["ui", "font_family"],
        "ui" => %{"font_family" => "OpenDyslexic"}
      })

      # Without this push, the initial `<head>` (rendered once via root.html.heex) keeps
      # the old font across LV navigations until a full HTTP refresh.
      assert_push_event(view, "set_font", %{
        font_name: "OpenDyslexic",
        href: "/fonts/opendyslexic.css"
      })
    end

    test "As a user I want to select a different language" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)

      {:ok, refreshed_view, _html} = live(conn, "/dashboard")

      assert refreshed_view
             |> element("span[data-role=locale]")
             |> render() =~ "en"

      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_language]")
      |> render_change(%{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => "fr"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, "/dashboard")

      assert refreshed_view
             |> element("span[data-role=locale]")
             |> render() =~ "fr"

      #  assert refreshed_view
      #  |> has_element?("span[data-role=locale]", "it")
    end

    # test "As a user I want to hide brand name" do
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/appearance"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_brand]")
    #   |> render_change(%{"Elixir.Bonfire.UI.Common.LogoLive" => %{"only_logo" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, next)
    #   # open_browser(refreshed_view)

    #   refute refreshed_view
    #          |> has_element?("div[data-id=logo] div[data-scope=logo_name]")
    # end

    # test "As a user I want to change avatar shape to square" do
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/appearance"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_avatar_shape]")
    #   |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"shape" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, "/@#{alice.character.username}")

    #   assert refreshed_view
    #          |> has_element?("div[data-scope=avatar]")

    #   assert refreshed_view
    #          |> has_element?("div[data-scope=avatar] div[data-square]")
    # end

    test "As a user I want to set the animal avatar" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/behaviours"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_animal_avatar]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"animal_avatars" => "false"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      refute refreshed_view
             |> has_element?("svg[data-scope=animal_avatar]")
    end

    # test "As a user I want to set the compact layout" do
    #   account = fake_account!()
    #   alice = fake_user!(account)

    #   attrs = %{
    #     post_content: %{summary: "summary", html_body: "first post"}
    #   }

    #   assert {:ok, post} =
    #            Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/behaviours"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_compact_layout]")
    #   |> render_change(%{"ui" => %{"compact" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, "/post/#{post.id}")

    #   # open_browser(refreshed_view)
    #   assert refreshed_view
    #          |> has_element?("article[data-compact]")
    # end
  end

  describe "Behaviours" do
    # test "As a user I want to hide avatar from the layout" do
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/behaviours"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_hide_avatar]")
    #   |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"hide_avatars" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, next)

    #   refute refreshed_view
    #          |> has_element?("div[data-scope=sticky_menu] div[data-scope=avatar]")
    # end

    test "how many items to show in feeds and other lists" do
    end
  end

  describe "Instance blocks scope switcher (#2018)" do
    test "the user/account/instance scope switcher is NOT shown on the instance blocks page" do
      account = fake_account!()
      admin = fake_admin!(account)
      conn = conn(user: admin, account: account)

      {:ok, view, _html} = live(conn, "/settings/instance/boundaries/blocked")

      # The persona switcher links to per-user/account settings that don't exist for
      # blocks (account-level blocks aren't a thing, and /settings/user/blocked has no
      # settings page → "No settings available"). So it must not be shown here. #2018
      refute view |> has_element?("a[href^='/settings/user/blocked']")
      refute view |> has_element?("a[href^='/settings/account/blocked']")
    end
  end

  describe "Instance federation-mode selector (#2056)" do
    setup do
      on_exit(fn ->
        parent = self()

        Task.start(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Bonfire.Common.Repo, parent, self())
          Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, false)
        end)
      end)

      account = fake_account!()
      admin = fake_admin!(account)
      conn = conn(user: admin, account: account)
      {:ok, conn: conn, admin: admin, account: account}
    end

    test "all four federation-mode cards are offered", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings/instance/configuration")

      for value <- ["true", "allowlist_only", "manual", "false"] do
        assert view
               |> has_element?("input[name='activity_pub[instance][federating]'][value=#{value}]"),
               "expected a federation-mode card with value=#{value}"
      end
    end

    # saved instance setting -> {radio card `value` pre-selected, computed federation_mode}
    @mode_cases [
      {true, "true", true},
      {:allowlist_only, "allowlist_only", :allowlist_only},
      {:manual, "manual", nil},
      {false, "false", false}
    ]

    for {stored, expected_value, expected_mode} <- @mode_cases do
      @stored stored
      @expected_value expected_value
      @expected_mode expected_mode

      test "highlights the #{inspect(@stored)} card and only that one (#2056)", %{conn: conn} do
        Bonfire.Common.Settings.set([activity_pub: [instance: [federating: @stored]]],
          scope: :instance,
          skip_boundary_check: true
        )

        {:ok, view, _html} = live(conn, "/settings/instance/configuration")

        assert view
               |> has_element?(
                 "input[name='activity_pub[instance][federating]'][value=#{@expected_value}][checked]"
               ),
               "expected the #{@expected_value} card to be checked"

        # none of the other cards may be checked
        for other <- ["true", "allowlist_only", "manual", "false"], other != @expected_value do
          refute view
                 |> has_element?(
                   "input[name='activity_pub[instance][federating]'][value=#{other}][checked]"
                 ),
                 "did not expect the #{other} card to be checked"
        end
      end

      test "clicking the #{inspect(@stored)} card persists it (and stays highlighted on reload)",
           %{conn: conn} do
        # start from a different mode so the change is meaningful
        Bonfire.Common.Settings.set([activity_pub: [instance: [federating: true]]],
          scope: :instance,
          skip_boundary_check: true
        )

        {:ok, view, _html} = live(conn, "/settings/instance/configuration")

        # selecting a card fires the form's phx-change → Settings:set
        view
        |> element("form[data-scope=set_federation]")
        |> render_change(%{
          "scope" => "instance",
          "activity_pub" => %{"instance" => %{"federating" => @expected_value}}
        })

        # the change must actually persist as the computed instance federation_mode
        assert Bonfire.Federate.ActivityPub.federation_mode() == @expected_mode,
               "expected federation_mode() to be #{inspect(@expected_mode)} after saving"

        # ...and a fresh mount must reflect the saved choice
        {:ok, reloaded, _html} = live(conn, "/settings/instance/configuration")

        assert reloaded
               |> has_element?(
                 "input[name='activity_pub[instance][federating]'][value=#{@expected_value}][checked]"
               ),
               "expected the #{@expected_value} card to remain checked after saving"
      end
    end
  end

  describe "User federation-mode selector (#2056, shared component)" do
    setup do
      # Instance federation settings persist in Application env / DB and are NOT rolled back by the
      # Ecto sandbox, so earlier tests in this describe (e.g. "instance manual"/"instance allowlist")
      # leak their restrictive instance mode into later tests — clamping/hiding the `true` and
      # `allowlist_only` user cards. Reset to the open default before each test so the highlight
      # tests see all four cards reflect the user's own saved choice. See bonfire-app#2056.
      Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, false)
      Bonfire.Federate.ActivityPub.set_federating(:instance, true)

      on_exit(fn ->
        parent = self()

        Task.start(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Bonfire.Common.Repo, parent, self())
          Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, false)
        end)
      end)

      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      {:ok, conn: conn, alice: alice, account: account}
    end

    # --- option visibility, constrained by the instance's own mode ---

    test "instance open → all four user options are offered", %{conn: conn} do
      Bonfire.Federate.ActivityPub.set_federating(:instance, true)

      {:ok, view, _html} = live(conn, "/settings/user/safety")

      for value <- ["true", "allowlist_only", "manual", "false"] do
        assert view
               |> has_element?("input[name='activity_pub[user_federating]'][value=#{value}]"),
               "expected the #{value} option to be offered"
      end
    end

    test "instance allowlist-only → the Open option is hidden", %{conn: conn} do
      Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, true)

      {:ok, view, _html} = live(conn, "/settings/user/safety")

      refute view |> has_element?("input[name='activity_pub[user_federating]'][value=true]")

      assert view
             |> has_element?("input[name='activity_pub[user_federating]'][value=allowlist_only]")

      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=manual]")
      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=false]")
    end

    test "instance manual → only manual and disabled are offered", %{conn: conn} do
      Bonfire.Common.Settings.set([activity_pub: [instance: [federating: :manual]]],
        scope: :instance,
        skip_boundary_check: true
      )

      {:ok, view, _html} = live(conn, "/settings/user/safety")

      refute view |> has_element?("input[name='activity_pub[user_federating]'][value=true]")

      refute view
             |> has_element?("input[name='activity_pub[user_federating]'][value=allowlist_only]")

      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=manual]")
      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=false]")
    end

    # --- highlight reflects the user's saved (effective) choice ---

    for {stored, expected_value} <- [
          {true, "true"},
          {:allowlist_only, "allowlist_only"},
          {:manual, "manual"},
          {false, "false"}
        ] do
      @stored stored
      @expected_value expected_value

      test "saved user mode #{inspect(@stored)} highlights the #{@expected_value} card",
           %{conn: conn, alice: alice} do
        Bonfire.Common.Settings.put([:activity_pub, :user_federating], @stored,
          current_user: alice
        )

        {:ok, view, _html} = live(conn, "/settings/user/safety")

        assert view
               |> has_element?(
                 "input[name='activity_pub[user_federating]'][value=#{@expected_value}][checked]"
               ),
               "expected the #{@expected_value} card to be checked"
      end
    end
  end

  describe "Privacy & Settings" do
    test "default boundary" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/settings/user/bonfire_ui_boundaries")

      # The picker is a select-style dropdown: the currently-selected audience
      # is shown in the dropdown trigger (not as a highlighted grid tile).
      # Default is "public", so the trigger should read "Public".
      assert view
             |> has_element?(
               "[data-scope=safety_boundary_default] #boundaries_general_access_list_trigger",
               "Public"
             )

      # ...and the selected option in the panel carries a check marker.
      assert view
             |> has_element?(
               "[data-scope=safety_boundary_default] button[data-scope=public_boundary] [iconify='ph:check-bold']"
             )

      refute view
             |> has_element?(
               "[data-scope=safety_boundary_default] button[data-scope=local_boundary] [iconify='ph:check-bold']"
             )

      # The options live in the (DOM-rendered) dropdown panel; pick "Local".
      view
      |> element("[data-scope=safety_boundary_default] button[data-scope=local_boundary]")
      |> render_click()

      # open_browser(view)
      {:ok, refreshed_view, _html} = live(conn, "/settings/user/bonfire_ui_boundaries")

      # After selecting, the trigger reflects the new default audience...
      assert refreshed_view
             |> has_element?(
               "[data-scope=safety_boundary_default] #boundaries_general_access_list_trigger",
               "Local"
             )

      # ...and the check marker moves to the newly-selected option.
      assert refreshed_view
             |> has_element?(
               "[data-scope=safety_boundary_default] button[data-scope=local_boundary] [iconify='ph:check-bold']"
             )
    end
  end
end
