defmodule Bonfire.UI.Me.ProfileHoverCardPageTest do
  @moduledoc """
  The hover card's container is mounted once in the layout for logged-in viewers only. The hook asks for a card through the hovered link, so the post that link sits in hands over the user it already loaded; the counts and "Followed by" load after the card shows (plans/profile-hover-card.md, "Data reuse").
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  import Phoenix.LiveViewTest

  alias Bonfire.Social.Graph.Follows

  @load "Bonfire.UI.Me.ProfileHoverCardLive:load"
  @loaded "profile_hover_card:loaded"

  setup do
    account = fake_account!()
    {:ok, account: account, me: fake_user!(account), them: fake_user!()}
  end

  test "from a post, the card shows who they are without querying users, from the user the post already loaded",
       %{account: account, me: me, them: them} do
    publish!(them)

    view = open_feed(me, account)
    html = render_async(view)
    user_queries = watch_user_queries(view)

    view
    |> with_target(post_root(html, them))
    |> render_hook(@load, %{"id" => them.id})

    assert_push_event(view, @loaded, %{id: id, found: true})
    assert id == them.id

    doc = fragment(view, "#profile_hover_card")
    assert text(doc, "a[data-role=user_preview_name]") =~ them.profile.name
    assert text(doc, "[data-role=user_preview_handle]") =~ them.character.username
    assert [_] = Floki.find(doc, "[data-role=user_preview_bio]")
    assert [_] = Floki.find(doc, "[data-role=user_preview_website]")

    refute_received {^user_queries, _query}
  end

  test "outside a post, the card loads by id; anything that isn't a user gives no card; a guest's page has no card",
       %{account: account, me: me, them: them} do
    post = publish!(me)
    view = open_feed(me, account)

    push_load(view, them.id)
    assert_push_event(view, @loaded, %{id: id, found: true})
    assert id == them.id
    assert text(fragment(view, "#profile_hover_card"), "a[data-role=user_preview_name]") =~ them.profile.name

    push_load(view, post.id)
    assert_push_event(view, @loaded, %{found: false})

    # checked in the same test so it can't pass before the container exists
    {:ok, _guest_view, guest_html} = live(conn(), "/feed/local")
    assert Floki.find(Floki.parse_document!(guest_html), "#profile_hover_card") == []
  end

  test "the loaded card: name and avatar link to the profile, bio and website, then 'Followed by', and Follow",
       %{account: account, me: me, them: them} do
    ana = fake_user!()
    {:ok, _} = Follows.follow(me, ana)
    {:ok, _} = Follows.follow(ana, them)

    doc = loaded_card(me, account, them)

    assert [name_link] = Floki.find(doc, "a[data-role=user_preview_name]")
    assert Floki.text(name_link) =~ them.profile.name
    # the card holds a follow button, so the name link must not cover it
    refute Floki.attribute(name_link, "class") |> hd() =~ "after:inset-0"
    assert [_] = Floki.find(doc, "a[data-role=user_preview_avatar_link]")

    assert [_] = Floki.find(doc, "[data-role=user_preview_bio]")
    assert [_] = Floki.find(doc, "[data-role=user_preview_website]")

    assert [_] = Floki.find(doc, "[data-role=familiar_follower_avatar]")
    assert text(doc, "[data-role=familiar_followers_text]") =~ ana.profile.name

    assert [_] = Floki.find(doc, "[data-id=follow]")

    # counts follow Vanity Metrics, which is off by default
    assert Floki.find(doc, "[data-role=profile_followers_count]") == []
  end

  test "the loaded card shows counts when I turned on Vanity Metrics",
       %{account: account, me: me, them: them} do
    me =
      Bonfire.Common.Utils.current_user(
        Bonfire.Common.Settings.put([:ui, :show_activity_counts], true, current_user: me)
      )

    doc = loaded_card(me, account, them)

    assert [_] = Floki.find(doc, "[data-role=profile_followers_count]")
    assert [_] = Floki.find(doc, "[data-role=profile_following_count]")
  end

  test "hovering A then B quickly ends with B's 'Followed by', never A's",
       %{account: account, me: me, them: b} do
    [a, friend_of_a, friend_of_b] = for _ <- 1..3, do: fake_user!()
    {:ok, _} = Follows.follow(me, friend_of_a)
    {:ok, _} = Follows.follow(me, friend_of_b)
    {:ok, _} = Follows.follow(friend_of_a, a)
    {:ok, _} = Follows.follow(friend_of_b, b)

    view = open_feed(me, account)

    push_load(view, a.id)
    push_load(view, b.id)
    render_async(view)

    followed_by = text(fragment(view, "#profile_hover_card"), "[data-role=familiar_followers_text]")
    assert followed_by =~ friend_of_b.profile.name
    refute followed_by =~ friend_of_a.profile.name
  end

  # opening and closing the sheet is the browser's (`showModal()` in the hook); these check what the server puts in it
  describe "on touch, a tap opens the card's own bottom sheet, filled by the same load" do
    test "a tap's load fills the sheet; the desktop panel stays empty",
         %{account: account, me: me, them: them} do
      view = open_feed(me, account)

      push_load(view, them.id, sheet: true)
      assert_push_event(view, @loaded, %{id: id, found: true})
      assert id == them.id

      sheet = fragment(view, "#profile_hover_card_sheet")
      assert text(sheet, "a[data-role=user_preview_name]") =~ them.profile.name
      assert [_] = Floki.find(sheet, "[data-id=follow]")

      assert Floki.find(fragment(view, "#profile_hover_card_panel"), "a[data-role=user_preview_name]") == []
    end

    test "the counts and 'Followed by' reach the sheet once loaded; the bio isn't clamped",
         %{account: account, me: me, them: them} do
      ana = fake_user!()
      {:ok, _} = Follows.follow(me, ana)
      {:ok, _} = Follows.follow(ana, them)

      view = open_feed(me, account)

      push_load(view, them.id, sheet: true)
      render_async(view)

      sheet = fragment(view, "#profile_hover_card_sheet")
      assert text(sheet, "[data-role=familiar_followers_text]") =~ ana.profile.name

      # S2: CSS-only differences from the card, set on the body's wrapper
      assert [wrapper] = Floki.find(sheet, "[data-role=profile_hover_card_body]")
      assert Floki.attribute(wrapper, "class") |> hd() =~ "line-clamp-none"
    end

    test "a hover after a tap shows the card in the panel again",
         %{account: account, me: me, them: them} do
      view = open_feed(me, account)

      push_load(view, them.id, sheet: true)
      push_load(view, them.id)

      assert text(fragment(view, "#profile_hover_card_panel"), "a[data-role=user_preview_name]") =~ them.profile.name
      assert Floki.find(fragment(view, "#profile_hover_card_sheet"), "a[data-role=user_preview_name]") == []
    end

    test "a tap on something that isn't a user leaves the sheet empty",
         %{account: account, me: me} do
      post = publish!(me)
      view = open_feed(me, account)

      push_load(view, post.id, sheet: true)
      assert_push_event(view, @loaded, %{found: false})

      assert Floki.find(fragment(view, "#profile_hover_card_sheet"), "[data-role=profile_hover_card_body]") == []
    end
  end

  defp open_feed(me, account) do
    {:ok, view, _html} = live(conn(user: me, account: account), "/feed/local")
    view
  end

  defp loaded_card(me, account, them) do
    view = open_feed(me, account)

    push_load(view, them.id)
    render_async(view)
    fragment(view, "#profile_hover_card")
  end

  defp push_load(view, id, opts \\ []) do
    view
    |> element("#profile_hover_card")
    |> render_hook(@load, %{"id" => id, "sheet" => opts[:sheet] == true})
  end

  defp fragment(view, selector) do
    view
    |> element(selector)
    |> render()
    |> Floki.parse_fragment!()
  end

  # the post's root element, so the event reaches its `ActivityLive` as it does from the hook's `pushEventTo(link, ...)`
  defp post_root(html, user) do
    html
    |> Floki.parse_document!()
    |> Floki.find("article[data-id=activity]")
    |> Enum.find(&(Floki.find(&1, "[data-hovercard-id='#{user.id}']") != []))
    |> Floki.attribute("id")
    |> then(fn [id] -> "[id='#{id}']" end)
  end

  # queries on the users table made by the LiveView process itself; the extras run in their own process, so they aren't counted
  defp watch_user_queries(view) do
    ref = make_ref()
    test_pid = self()
    users = Bonfire.Data.Identity.User.__schema__(:source)
    event = Bonfire.Common.Config.repo().config()[:telemetry_prefix] ++ [:query]

    :telemetry.attach(
      ref,
      event,
      fn _event, _measurements, metadata, _config ->
        if self() == view.pid and metadata[:source] == users,
          do: send(test_pid, {ref, metadata[:query]})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(ref) end)
    ref
  end

  defp publish!(user),
    do: Bonfire.Posts.Fake.fake_post!(user, "public", %{post_content: %{html_body: "a post"}})

  defp text(doc, selector) do
    doc
    |> Floki.find(selector)
    |> Floki.text()
    |> String.trim()
  end
end
