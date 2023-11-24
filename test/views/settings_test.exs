defmodule Bonfire.UI.Me.SettingsTest do
  use Bonfire.UI.Me.ConnCase, async: false
  import Phoenix.LiveViewTest
  use Mneme
  alias Bonfire.Social.Posts

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

      assert "Luciole" ==
               view
               |> element("body")
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

    test "As a user I want to hide avatar from the layout" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
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

    test "As a user I want to set the animal avatar" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
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

    test "As a user I want to hide actions on feed" do
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
      |> element("form[data-scope=set_hide_actions_on_feed]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.Activity.ActionsLive" => %{
          "feed" => %{"hide_until_hovered" => "true"}
        }
      })

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, "/")

      # open_browser(refreshed_view)
      auto_assert true <-
                    refreshed_view
                    |> has_element?("article div[data-id=activity_actions][data-hide]")
    end

    test "As a user I want to hide actions on discussion" do
      account = fake_account!()
      alice = fake_user!(account)

      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      attrs_reply = %{
        post_content: %{
          summary: "summary",
          name: "name 2",
          html_body: "<p>reply to first post</p>"
        },
        reply_to_id: post.id
      }

      assert {:ok, post_reply} =
               Posts.publish(current_user: alice, post_attrs: attrs_reply, boundary: "public")

      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_hide_actions_on_discussion]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.Activity.ActionsLive" => %{
          "thread" => %{"hide_until_hovered" => "true"}
        }
      })

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, "/post/#{post.id}")

      # open_browser(refreshed_view)
      auto_assert true <-
                    refreshed_view
                    |> has_element?("article div[data-id=activity_actions][data-hide]")
    end
  end

  describe "Behaviours" do
    test "Feed activities" do
    end

    test "default feed" do
    end

    test "feed default time limit" do
    end

    test "feed defaykt sort" do
    end

    test "how many items to show in feeds and other lists" do
    end

    test "infinite scrolling" do
    end

    test "sensitive media" do
    end

    test "hide media" do
    end

    test "discussion default layout" do
    end

    test "discussion default sort" do
    end

    test "highlight notifications indicator" do
    end

    test "show reaction counts (likes/boosts)" do
    end
  end
end
