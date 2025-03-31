defmodule Bonfire.UI.Me.ProfileTest do
  # not async to try to avoid this error in CI: (Postgrex.Error) ERROR 57014 (query_canceled) canceling statement due to user request
  use Bonfire.UI.Me.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias Bonfire.Social.Graph.Follows

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
end
