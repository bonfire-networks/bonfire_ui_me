defmodule Bonfire.UI.Me.ProfileTest do
  # not async to try to avoid this error in CI: (Postgrex.Error) ERROR 57014 (query_canceled) canceling statement due to user request
  use Bonfire.UI.Me.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias Bonfire.Social.Graph.Follows

  @tag :could
  test "If a user follows me, I want to have a visual feedback in their profile" do
    account = fake_account!()
    # Given a user
    alice = fake_user!(account)
    # And a user that follows me
    bob = fake_user!(account)
    Follows.follow(bob, alice)
    # When I visit the profile of the user that follows me
    conn = conn(user: alice, account: account)
    next = Bonfire.Common.URIs.path(bob)
    {:ok, _view, html} = live(conn, next)
    # Then I should see a visual feedback in their profile
    assert html =~ "Follows you"

    # Given a third user
    carl = fake_user!(account)
    # When I visit the profile of the user that does not follows me
    next = Bonfire.Common.URIs.path(carl)
    {:ok, _view, html} = live(conn, next)
    # Then I should not see the visual feedback in their profile
    refute html =~ "Follows you"
  end
end
