defmodule Bonfire.UI.Me.ProfileTest do
  # not async to try to avoid this error in CI: (Postgrex.Error) ERROR 57014 (query_canceled) canceling statement due to user request
  use Bonfire.UI.Me.ConnCase, async: false
  use Mneme
  import Phoenix.LiveViewTest
  import Tesla.Mock
  # alias Bonfire.Files.Simulation, as: FakeFiles

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Common.Config
  alias Bonfire.Social.Fake
  alias Bonfire.Federate.ActivityPub.Simulate

  def fake_remote_user!() do
    {:ok, user} = Bonfire.Federate.ActivityPub.Simulate.fake_remote_user()
    user
  end

  test "If a user follows me, I want to have a visual feedback in their profile" do
    account = fake_account!()
    alice = fake_user!(account)
    bob = fake_user!(account)
    carl = fake_user!(account)
    conn = conn(user: alice, account: account)

    {:ok, _} = Follows.follow(bob, alice)

    conn
    |> visit("/@#{bob.character.username}")
    |> assert_has("[data-role=follows_you]", text: "Follows you")

    conn
    |> visit("/@#{carl.character.username}")
    |> refute_has("[data-role=follows_you]", text: "Follows you")
  end


  test "When a remote user boosts my post, when i navigate to their profile, I want to see my original boosted activity in their profile as local activity, not a remote one" do
    # Mock HTTP requests for remote user fetching
    mock(fn
      %{method: :get, url: "https://mocked.local/users/karen"} ->
        %Tesla.Env{
          status: 200,
          body: Jason.encode!(Simulate.actor_json("https://mocked.local/users/karen")),
          headers: [{"content-type", "application/activity+json"}]
        }
    end)

    account = fake_account!()
    alice = fake_user!(account)
    bob = Fake.fake_remote_user!()

    {:ok, post} = Posts.publish(
      current_user: alice,
      boundary: "public",
      post_attrs: %{
        post_content: %{
          html_body: "Hello world!"
        }
      }
    )

    # Bob boosts Alice's post
    {:ok, _} = Boosts.boost(bob, post)

    # Navigate to Bob's profile
    conn = conn(user: alice, account: account)
    conn
    |> visit("/@#{bob.character.username}")
    |> refute_has("[data-id=peered]")
  end
end
