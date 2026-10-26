defmodule Bonfire.UI.Me.ProfileHoverCardLiveTest do
  @moduledoc """
  What the profile hover card shows for one user: `ProfileHoverCardLive.load_identity/2` (who they are, shown at once) and `load_extras/2` (whether they follow me, "Followed by", and counts only when the viewer turned on Vanity Metrics, loaded after). It's the same lookup as the profile page, so it hides nothing the profile wouldn't (see plans/profile-hover-card.md, A-BB1).
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

  test "a local user I don't follow: no counts by default, not even loaded", %{me: me, them: them} do
    assert {:ok, user} = ProfileHoverCardLive.load_identity(me, them.id)
    assert user.id == them.id

    extras = ProfileHoverCardLive.load_extras(me, user)
    assert extras.follows_me == false
    assert extras.followers_count == nil
    assert extras.following_count == nil
    # with Vanity Metrics off, the counts aren't loaded at all
    assert %Ecto.Association.NotLoaded{} = user.character.follow_count
  end

  test "an id that isn't a user gives no card", %{me: me} do
    post =
      Bonfire.Posts.Fake.fake_post!(me, "public", %{post_content: %{html_body: "not a person"}})

    assert {:error, :not_found} = ProfileHoverCardLive.load_identity(me, post.id)
  end

  test "an id that isn't a valid id gives no card, rather than crashing the page", %{me: me} do
    assert {:error, :not_found} = ProfileHoverCardLive.load_identity(me, "not-an-id")
  end

  test "no card without a current user", %{them: them} do
    assert {:error, :not_found} = ProfileHoverCardLive.load_identity(nil, them.id)
  end

  test "counts show when I turned on Vanity Metrics", %{me: me, them: them} do
    me =
      Bonfire.Common.Utils.current_user(
        Bonfire.Common.Settings.put([:ui, :show_activity_counts], true, current_user: me)
      )

    {:ok, _} = Follows.follow(fake_user!(), them)

    extras = ProfileHoverCardLive.load_extras(me, them)
    assert extras.followers_count == 1
    assert extras.following_count == 0
  end

  test "someone I silenced still gets a card, as their profile page does", %{me: me, them: them} do
    {:ok, _} = Bonfire.Boundaries.Blocks.block(them, :silence, current_user: me)

    assert {:ok, %{id: id}} = ProfileHoverCardLive.load_identity(me, them.id)
    assert id == them.id
  end

  test "the people I follow who follow them come with the card", %{me: me, them: them} do
    friend = fake_user!()
    {:ok, _} = Follows.follow(me, friend)
    {:ok, _} = Follows.follow(friend, them)

    extras = ProfileHoverCardLive.load_extras(me, them)
    assert Enum.map(extras.familiar_followers, & &1.id) == [friend.id]
    assert extras.familiar_followers_total == 1
  end

  test "follow state is read fresh on every load, never cached", %{me: me, them: them} do
    assert %{follows_me: false} = ProfileHoverCardLive.load_extras(me, them)

    {:ok, _} = Follows.follow(them, me)

    assert %{follows_me: true} = ProfileHoverCardLive.load_extras(me, them)
  end

  describe "remote users" do
    setup %{me: me} do
      Tesla.Mock.mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)

      # ProcessTree reads this, so it scopes the federation mode to this test
      Process.put(:federating, true)

      # creating the remote actor goes through ActivityPub's fetcher, which reads Application env rather than the process
      instance_config = Application.get_env(:activity_pub, :instance)

      Application.put_env(
        :activity_pub,
        :instance,
        Keyword.put(instance_config, :federating, true)
      )

      on_exit(fn -> Application.put_env(:activity_pub, :instance, instance_config) end)

      {:ok, remote} = Bonfire.Federate.ActivityPub.Simulate.fake_remote_user()
      {:ok, me: me, remote: remote}
    end

    # the viewer's own follow state and whether following a remote actor is allowed come from the follow button's own preload (the card doesn't preset my_follow), covered by the #647 tests in profile_test.exs
    # may never reach Tesla; kept to catch a future fetch on hover
    test "loading a card makes no federation request", %{me: me, remote: remote} do
      test_pid = self()

      Tesla.Mock.mock_global(fn env ->
        send(test_pid, {:http_called, env.url})
        %Tesla.Env{status: 404}
      end)

      assert {:ok, user} = ProfileHoverCardLive.load_identity(me, remote.id)
      assert %{} = ProfileHoverCardLive.load_extras(me, user)
      refute_received {:http_called, _}
    end
  end
end
