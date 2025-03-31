defmodule Bonfire.UI.Me.AdminTest do
  use Bonfire.UI.Me.ConnCase, async: true

  alias Bonfire.Social.Fake
  alias Bonfire.Me.Users
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Posts

  test "As an admin I want to make another user admin" do
    account = fake_account!()
    account2 = fake_account!()
    alice = fake_user!(account2)
    admin = fake_admin!(account)

    conn = conn(user: admin, account: account)
    conn
    |> visit("/@#{alice.character.username}")
    |> click_button("Make admin")
    |> assert_has("[role=alert]", text: "They are now an admin!")
  end
end
