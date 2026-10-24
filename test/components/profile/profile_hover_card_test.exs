defmodule Bonfire.UI.Me.ProfileHoverCardLiveTest do
  @moduledoc """
  `ProfileHoverCardLive.load_card/2` gathers what the profile hover card shows for one user: who they are, the follow state in both directions, whether following is allowed under the current federation mode, and counts only when the viewer turned on Vanity Metrics. It's the same lookup as the profile page, so it hides nothing the profile wouldn't (see plans/profile-hover-card.md, A-BB1).
  """
  # one describe changes Application env, so this module can't run alongside async ones
  use Bonfire.UI.Me.DataCase, async: false

  import Bonfire.Me.Fake

  alias Bonfire.UI.Me.ProfileHoverCardLive
  alias Bonfire.Social.Graph.Follows

  setup do
    me = fake_user!()
    them = fake_user!()
    {:ok, me: me, them: them}
  end

  test "a local user I don't follow, with no counts by default", %{me: me, them: them} do
    assert {:ok, card} = ProfileHoverCardLive.load_card(me, them.id)

    assert card.user.id == them.id
    assert card.follows_me == false
    assert card.followers_count == nil
    assert card.following_count == nil
  end

  test "someone who follows me", %{me: me, them: them} do
    {:ok, _} = Follows.follow(them, me)

    assert {:ok, %{follows_me: true}} = ProfileHoverCardLive.load_card(me, them.id)
  end

  test "an id that isn't a user gives no card", %{me: me} do
    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: me,
        boundary: "public",
        post_attrs: %{post_content: %{html_body: "not a person"}}
      )

    assert {:error, :not_found} = ProfileHoverCardLive.load_card(me, post.id)
  end

  test "an id that isn't a valid id gives no card, rather than crashing the page", %{me: me} do
    assert {:error, :not_found} = ProfileHoverCardLive.load_card(me, "not-an-id")
  end

  test "no card without a current user", %{them: them} do
    assert {:error, :not_found} = ProfileHoverCardLive.load_card(nil, them.id)
  end

  test "counts show when I turned on Vanity Metrics", %{me: me, them: them} do
    me =
      Bonfire.Common.Utils.current_user(
        Bonfire.Common.Settings.put([:ui, :show_activity_counts], true, current_user: me)
      )

    {:ok, _} = Follows.follow(fake_user!(), them)

    assert {:ok, card} = ProfileHoverCardLive.load_card(me, them.id)
    assert card.followers_count == 1
    assert card.following_count == 0
  end

  test "with Vanity Metrics off, counts are neither shown nor loaded", %{me: me, them: them} do
    assert {:ok, card} = ProfileHoverCardLive.load_card(me, them.id)

    assert card.followers_count == nil
    assert card.following_count == nil
    assert %Ecto.Association.NotLoaded{} = card.user.character.follow_count
  end

  test "someone I silenced still gets a card, as their profile page does", %{me: me, them: them} do
    {:ok, _} = Bonfire.Boundaries.Blocks.block(them, :silence, current_user: me)

    assert {:ok, %{user: %{id: id}}} = ProfileHoverCardLive.load_card(me, them.id)
    assert id == them.id
  end

  test "the people I follow who follow them come with the card", %{me: me, them: them} do
    friend = fake_user!()
    {:ok, _} = Follows.follow(me, friend)
    {:ok, _} = Follows.follow(friend, them)

    assert {:ok, card} = ProfileHoverCardLive.load_card(me, them.id)
    assert Enum.map(card.familiar_followers, & &1.id) == [friend.id]
    assert card.familiar_followers_total == 1
  end

  test "follow state is read fresh on every load, never cached", %{me: me, them: them} do
    assert {:ok, %{follows_me: false}} = ProfileHoverCardLive.load_card(me, them.id)

    {:ok, _} = Follows.follow(them, me)

    assert {:ok, %{follows_me: true}} = ProfileHoverCardLive.load_card(me, them.id)
  end

  describe "remote users" do
    setup %{me: me} do
      Tesla.Mock.mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)

      # ProcessTree reads this, so it scopes the federation mode to this test
      Process.put(:federating, true)

      # creating the remote actor goes through ActivityPub's fetcher, which reads Application env rather than the process
      instance_config = Application.get_env(:activity_pub, :instance)
      Application.put_env(:activity_pub, :instance, Keyword.put(instance_config, :federating, true))
      on_exit(fn -> Application.put_env(:activity_pub, :instance, instance_config) end)

      {:ok, remote} = Bonfire.Federate.ActivityPub.Simulate.fake_remote_user()
      {:ok, me: me, remote: remote}
    end

    # the viewer's own follow state and whether following a remote actor is allowed come from the follow button's own preload (the card doesn't preset my_follow), covered by the #647 tests in profile_test.exs
    # UNCERTAIN: load_card may never reach Tesla at all, in which case this proves little. Kept to catch a future change that fetches the actor on hover.
    test "loading a card makes no federation request", %{me: me, remote: remote} do
      test_pid = self()

      Tesla.Mock.mock_global(fn env ->
        send(test_pid, {:http_called, env.url})
        %Tesla.Env{status: 404}
      end)

      assert {:ok, _} = ProfileHoverCardLive.load_card(me, remote.id)
      refute_received {:http_called, _}
    end
  end
end
