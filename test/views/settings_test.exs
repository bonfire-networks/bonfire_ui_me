defmodule Bonfire.UI.Me.SettingsTest do
  use Bonfire.UI.Me.ConnCase, async: false
  use Mneme
  import Phoenix.LiveViewTest
  import Bonfire.Files.Simulation

  alias Bonfire.Social.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Follows
  alias Bonfire.Common.Config

  setup_all do
    orig1 = Config.get!(:pagination_hard_max_limit)

    orig2 = Config.get!(:default_pagination_limit)

    Config.put(:pagination_hard_max_limit, 10)

    Config.put(:default_pagination_limit, 10)

    on_exit(fn ->
      Config.put(:pagination_hard_max_limit, orig1)

      Config.put(:default_pagination_limit, orig2)
    end)
  end

  describe "Appearance" do
    test "As a user I want to select a different theme" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"theme" => %{"instance_theme" => "dracula"}}})

      assert view
             |> element("[data-theme=dracula]")
             |> has_element?()
    end

    # FIXME: find a way to check the font
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
      {:ok, refreshed_view, html} = live(conn, next)

      assert html =~ "fonts/luciole.css"
    end

    test "As a user I want to select a different language" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_language]")
      |> render_change(%{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => "it"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("span[data-role=locale]", "it")
    end

    test "As a user I want to switch composer ui" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_composer]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Common.SmartInputContainerLive" => %{
          "show_focused" => "true"
        }
      })

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("div#smart_input_container[data-focused]")
    end

    test "As a user I want to hide brand name" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_brand]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.LogoLive" => %{"only_logo" => "true"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)
      # open_browser(refreshed_view)

      auto_assert false <-
                    refreshed_view
                    |> has_element?("div[data-id=logo] div[data-scope=logo_name]")
    end

    test "As a user I want to change avatar shape to square" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_avatar_shape]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"shape" => "true"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("div[data-scope=avatar] div[data-square]")
    end

    test "As a user I want to set the animal avatar" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/behaviours"
      {:ok, view, _html} = live(conn, next)

      auto_assert true <-
                    view
                    |> has_element?("svg[data-scope=animal_avatar]")

      view
      |> element("form[data-scope=set_hide_avatar]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"animal_avatars" => "false"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert false <-
                    refreshed_view
                    |> has_element?("svg[data-scope=animal_avatar]")
    end

    test "As a user I want to set the compact layout" do
      account = fake_account!()
      alice = fake_user!(account)

      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_compact_layout]")
      |> render_change(%{"ui" => %{"compact" => "true"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, "/")

      # open_browser(refreshed_view)
      auto_assert true <-
                    refreshed_view
                    |> has_element?("article[data-compact]")
    end
  end

  describe "Behaviours" do
    test "As a user I want to hide avatar from the layout" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/behaviours"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_hide_avatar]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"hide_avatars" => "true"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert false <-
                    refreshed_view
                    |> has_element?("div[data-scope=sticky_menu] div[data-scope=avatar]")
    end

    test "how many items to show in feeds and other lists" do
    end

    test "highlight notifications indicator" do
      account = fake_account!()
      alice = fake_user!(account)
      bob = fake_user!(account)
      conn = conn(user: alice, account: account)

      # create a post that has 2 replies
      attrs = %{
        post_content: %{html_body: "alice post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      attrs = %{
        post_content: %{html_body: "reply 1"},
        reply_to_id: post.id
      }

      assert {:ok, p1} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      # change the preferences to sort by replies

      {:ok, view, _html} = live(conn, "/settings/user/preferences/behaviours")

      view
      |> element("form[data-scope=notification_highlight]")
      |> render_change(%{
        "Bonfire.UI.Common.BadgeCounterLive" => %{"highlight" => "true"}
      })

      {:ok, refreshed_view, _html} = live(conn, "/")
      # open_browser(refreshed_view)

      auto_assert refreshed_view
                  |> has_element?("div#badge_counter_notifications.bg-primary")
    end
  end

  describe "Privacy & Settings" do
    test "default boundary" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/settings/user/preferences/behaviours")

      auto_assert true <-
                    view
                    |> has_element?("span[data-scope=public-boundary-set]")

      view
      |> element("[data-scope=safety_boundary_default] button[data-scope=local_boundary]")
      |> render_click()

      # open_browser(view)
      {:ok, refreshed_view, _html} = live(conn, "/")

      auto_assert true <-
                    refreshed_view
                    |> has_element?("span[data-scope=local-boundary-set]")
    end
  end
end
