defmodule Bonfire.UI.Me.ProfileHoverCardPageTest do
  @moduledoc """
  The hover card's container is mounted once in the layout for logged-in viewers only, and answers the hook's `load` event with whether it found a user.
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  import Phoenix.LiveViewTest

  test "a logged-in viewer's page has the container and answers load; a guest's page has none" do
    account = fake_account!()
    me = fake_user!(account)
    them = fake_user!()

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: me,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "not a person"}}
      )

    {:ok, view, _html} = live(conn(user: me, account: account), "/feed/local")

    html =
      view
      |> element("#profile_hover_card")
      |> render_hook("load", %{"id" => them.id})

    assert_reply(view, %{id: id, found: true})
    assert id == them.id
    assert html =~ them.profile.name

    view
    |> element("#profile_hover_card")
    |> render_hook("load", %{"id" => post.id})

    assert_reply(view, %{found: false})

    # checked in the same test so it can't pass before the container exists
    {:ok, _guest_view, guest_html} = live(conn(), "/feed/local")
    assert Floki.find(Floki.parse_document!(guest_html), "#profile_hover_card") == []
  end

  test "the loaded card: name and avatar link to the profile, bio and website, 'Followed by', and Follow" do
    account = fake_account!()
    me = fake_user!(account)
    them = fake_user!()
    ana = fake_user!()
    {:ok, _} = Bonfire.Social.Graph.Follows.follow(me, ana)
    {:ok, _} = Bonfire.Social.Graph.Follows.follow(ana, them)

    doc = load_card(me, account, them)

    assert [name_link] = Floki.find(doc, "a[data-role=user_preview_name]")
    assert Floki.text(name_link) =~ them.profile.name
    # the card holds a follow button, so the name link must not cover it
    refute Floki.attribute(name_link, "class") |> hd() =~ "after:inset-0"
    assert [_] = Floki.find(doc, "a[data-role=user_preview_avatar_link]")

    assert [_] = Floki.find(doc, "[data-role=user_preview_bio]")
    assert [_] = Floki.find(doc, "[data-role=user_preview_website]")

    assert [_] = Floki.find(doc, "[data-role=familiar_follower_avatar]")

    assert Floki.find(doc, "[data-role=familiar_followers_text]") |> Floki.text() =~
             ana.profile.name

    assert [_] = Floki.find(doc, "[data-id=follow]")

    # counts follow Vanity Metrics, which is off by default
    assert Floki.find(doc, "[data-role=profile_followers_count]") == []
  end

  test "the loaded card shows counts when I turned on Vanity Metrics" do
    account = fake_account!()
    me = fake_user!(account)
    them = fake_user!()

    me =
      Bonfire.Common.Utils.current_user(
        Bonfire.Common.Settings.put([:ui, :show_activity_counts], true, current_user: me)
      )

    doc = load_card(me, account, them)

    assert [_] = Floki.find(doc, "[data-role=profile_followers_count]")
    assert [_] = Floki.find(doc, "[data-role=profile_following_count]")
  end

  defp load_card(me, account, them) do
    {:ok, view, _html} = live(conn(user: me, account: account), "/feed/local")

    view
    |> element("#profile_hover_card")
    |> render_hook("load", %{"id" => them.id})
    |> Floki.parse_fragment!()
  end
end
