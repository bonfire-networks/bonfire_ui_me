defmodule Bonfire.UI.Me.SettingsTest do
  use Bonfire.UI.Me.ConnCase, async: false
  import Phoenix.LiveViewTest
  use Mneme
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
      Config.put(:pagination_hard_max_limit, 10)

      Config.put(:default_pagination_limit, 10)

      # create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # create bob user
      bob = fake_user!(account)
      # create post by alice
      attrs = %{
        post_content: %{summary: "summary", name: "test post name", html_body: "first post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")

      # create a reply by bob
      attrs_reply = %{
        post_content: %{
          summary: "summary",
          name: "name 2",
          html_body: "<p>reply</p>"
        },
        reply_to_id: post.id
      }

      alice_post = %{
        post_content: %{
          html_body: "<p>nice day uh?</p>"
        },
        reply_to_id: post.id
      }

      assert {:ok, post_reply} =
               Posts.publish(current_user: bob, post_attrs: alice_post, boundary: "public")

      # boost the post
      assert {:ok, boost} = Boosts.boost(bob, post_reply)
      # bob follows alice
      assert {:ok, follow} = Follows.follow(alice, bob)

      assert {:ok, op2} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # navigate to the feed
      # I should see 3 posts: alice post, bob reply, boost
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/settings/user/preferences/behaviours")

      view
      |> element("form[data-scope=boosts]")
      |> render_change(%{
        "Elixir.Bonfire.Social.Feeds" => %{"include" => %{"boost" => "false"}}
      })

      view
      |> element("form[data-scope=replies]")
      |> render_change(%{
        "Elixir.Bonfire.Social.Feeds" => %{"include" => %{"reply" => "false"}}
      })

      view
      |> element("form[data-scope=follows]")
      |> render_change(%{
        "Elixir.Bonfire.Social.Feeds" => %{"include" => %{"follow" => "true"}}
      })

      view
      |> element("form[data-scope=outbox]")
      |> render_change(%{
        "Elixir.Bonfire.Social.Feeds" => %{"include" => %{"outbox" => "false"}}
      })

      # "Elixir.Bonfire.Social.Feeds" => %{"include" => %{"reply" => "false"}},
      # "Elixir.Bonfire.Social.Feeds" => %{"include" => %{"outbox" => "false"}}

      {:ok, _refreshed_view, html} = live(conn, "/feed/local")
      # assert that the feed contains only 1 element
      auto_assert true <-
                    html
                    |> Floki.find("[data-id=feed] article")
                    |> List.first()
                    |> Floki.text() =~ "first post"
    end

    test "default feed" do
      # create alice user
      account = fake_account!()
      alice = fake_user!(account)
      # create bob user
      bob = fake_user!(account)
      # create post by alice
      attrs = %{
        post_content: %{html_body: "alice post"}
      }

      assert {:ok, post} =
               Posts.publish(current_user: alice, post_attrs: attrs, boundary: "public")

      # create a post by bob
      attrs = %{
        post_content: %{html_body: "bob post"}
      }

      assert {:ok, p} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")
      # default feed is set to myfeed
      # check that the first post is the one alice created
      conn = conn(user: alice, account: account)
      {:ok, view, html} = live(conn, "/")

      # ensure the first post in the feed is alice's post
      auto_assert true <-
                    html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ "alice post"

      # change default feed to local
      {:ok, view, _html} = live(conn, "/settings/user/preferences/behaviours")

      view
      |> element("form[data-scope=default_feed]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.FeedLive" => %{"default_feed" => "local"}
      })

      # check that the first post is the one bob created
      {:ok, refreshed_view, refreshed_html} = live(conn, "/")

      auto_assert true <- html =~ "local"

      auto_assert true <-
                    refreshed_html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ "bob post"
    end

    # WIP: Not sure how to meaningfully test it
    test "feed default time limit" do
    end

    test "feed default sort" do
      # create 2 users
      account = fake_account!()
      alice = fake_user!(account)
      bob = fake_user!(account)
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

      attrs = %{
        post_content: %{html_body: "reply 2"},
        reply_to_id: post.id
      }

      assert {:ok, p2} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")
      # create a post that has 2 likes
      assert {:ok, like} = Likes.like(alice, p1)
      assert {:ok, like} = Likes.like(bob, p1)
      # create a post that has 2 boosts
      assert {:ok, boost} = Boosts.boost(alice, p2)
      assert {:ok, boost} = Boosts.boost(bob, p2)

      conn = conn(user: alice, account: account)
      {:ok, view, html} = live(conn, "/feed/local")
      open_browser(view)
      # check the first post is the last created: p2
      auto_assert true <-
                    html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ "reply 2"

      # change the preferences to sort by likes
      {:ok, v1, _html} = live(conn, "/settings/user/preferences/behaviours")

      v1
      |> element("form[data-scope=reactions_sort]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.FeedLive" => %{"sorty_by" => :num_likes}
      })

      #  |> debug("QUI")
      #  open_browser(v1)
      {:ok, refreshed_view, refreshed_html} = live(conn, "/feed/local")
      # check the first post is the one with most likes: p1
      auto_assert true <-
                    refreshed_html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ "reply 1"

      # change the preferences to sort by boost
      {:ok, v2, _html} = live(conn, "/settings/user/preferences/behaviours")

      v2
      |> element("form[data-scope=reactions_sort]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.FeedLive" => %{"sorty_by" => "num_boosts"}
      })

      {:ok, refreshed_view1, refreshed_html} = live(conn, "/feed/local")
      # check the first post is the one with most boosts: p2
      open_browser(refreshed_view1)

      auto_assert true <-
                    refreshed_html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ "reply 1"

      # change the preferences to sort by replies
      {:ok, v3, _html} = live(conn, "/settings/user/preferences/behaviours")

      v3
      |> element("form[data-scope=reactions_sort]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.FeedLive" => %{"sorty_by" => "num_replies"}
      })

      {:ok, refreshed_view2, refreshed_html} = live(conn, "/feed/local")
      open_browser(refreshed_view2)
      # check the first post is the one with most replies: post
      auto_assert true <-
                    refreshed_html
                    |> Floki.find("article")
                    |> List.first()
                    |> Floki.text() =~ "alice post"
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
      |> element("form[data-scope=set_thread_layout]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.ThreadLive" => %{"thread_mode" => "flat"}
      })

      next = "/discussion/#{post.id}"
      {:ok, refreshed_view, _html} = live(conn, next)
      open_browser(refreshed_view)

      auto_assert refreshed_view
                  |> has_element?("[data-role=comment-flat]")
    end

    test "discussion default sort" do
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
      open_browser(refreshed_view)

      auto_assert refreshed_view
                  |> has_element?("div#badge_counter_notifications.bg-primary")
    end

    test "show reaction counts (likes/boosts)" do
      # Process.put(:feed_live_update_many_preloads, :inline)
      Config.put(:feed_live_update_many_preloads, :inline)
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
        post_content: %{html_body: "reply 2"},
        reply_to_id: post.id
      }

      assert {:ok, p1} = Posts.publish(current_user: bob, post_attrs: attrs, boundary: "public")
      # create a post that has 2 likes
      assert {:ok, like} = Likes.like(alice, p1)
      assert {:ok, like} = Likes.like(bob, p1)
      # create a post that has 2 boosts
      assert {:ok, boost} = Boosts.boost(alice, p1)
      assert {:ok, boost} = Boosts.boost(bob, p1)

      {:ok, view, _html} = live(conn, "/settings/user/preferences/appearance")

      view
      |> element("form[data-scope=set_hide_actions_on_feed]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Social.Activity.ActionsLive" => %{
          "feed" => %{"hide_until_hovered" => "false"}
        }
      })

      {:ok, view, _html} = live(conn, "/settings/user/preferences/behaviours")

      view
      |> element("form[data-scope=set_show_reaction_counts]")
      |> render_change(%{
        "ui" => %{"show_activity_counts" => true}
      })

      {:ok, refreshed_view, _html} = live(conn, "/feed/local")
      live_pubsub_wait(view)
      open_browser(refreshed_view)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("[data-role=reply_count]")
    end
  end
end
