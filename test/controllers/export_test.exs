defmodule Bonfire.UI.Me.ExportTest do
  use Bonfire.UI.Me.ConnCase, async: true

  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Social.Graph.Import

  setup do
    account = fake_account!()
    me = fake_user!(account)

    conn = conn(user: me, account: account)

    {:ok, conn: conn, account: account, user: me}
  end

  test "export following works", %{user: user, conn: conn} do
    # Create users to follow
    followee1 = fake_user!("Followee1")
    followee2 = fake_user!("Followee2")

    # Create initial follows
    assert {:ok, _follow1} = Follows.follow(user, followee1)
    assert {:ok, _follow2} = Follows.follow(user, followee2)

    # Verify follows exist
    assert Follows.following?(user, followee1)
    assert Follows.following?(user, followee2)

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/following")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "Account address")

    # Verify actual usernames are in the export
    followee1_username = Bonfire.Me.Characters.display_username(followee1, true)
    followee2_username = Bonfire.Me.Characters.display_username(followee2, true)
    assert String.contains?(conn.resp_body, followee1_username)
    assert String.contains?(conn.resp_body, followee2_username)
  end

  test "export followers works", %{user: user, conn: conn} do
    # Create a user who will follow us
    follower = fake_user!("Follower")

    # Create follow relationship
    assert {:ok, _follow} = Follows.follow(follower, user)

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/followers")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "Account address")

    # Verify follower username is in the export
    follower_username = Bonfire.Me.Characters.display_username(follower, true)
    assert String.contains?(conn.resp_body, follower_username)
  end

  test "export follow requests works", %{user: user, conn: conn} do
    # Create a user that manually approves followers
    followee = fake_user!("FollowerUser", %{}, request_before_follow: true)

    # Create a follow request
    assert {:ok, _request} = Bonfire.Social.Graph.Follows.follow(user, followee)

    # Verify it's a request, not an immediate follow
    refute Bonfire.Social.Graph.Follows.following?(user, followee)
    assert Bonfire.Social.Graph.Follows.requested?(user, followee)

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/requests")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "Account address")

    # Verify request is present
    followee_username = Bonfire.Me.Characters.display_username(followee, true)
    assert String.contains?(conn.resp_body, followee_username)
  end

  test "export posts works", %{user: user, conn: conn} do
    # Create some posts
    assert {:ok, post1} =
             Bonfire.Posts.publish(
               current_user: user,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Test post 1 content"}}
             )

    assert {:ok, post2} =
             Bonfire.Posts.publish(
               current_user: user,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Test post 2 content"}}
             )

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/posts")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "ID")
    assert String.contains?(conn.resp_body, "Date")
    assert String.contains?(conn.resp_body, "Text")

    # Verify post content is in the export
    assert String.contains?(conn.resp_body, "Test post 1 content")
    assert String.contains?(conn.resp_body, "Test post 2 content")
  end

  test "export messages works", %{user: user, conn: conn} do
    # Create another user to message
    other_user = fake_user!("OtherUser")

    # Create some messages
    assert {:ok, message1} =
             Bonfire.Messages.send(user, %{post_content: %{html_body: "Hello message 1"}}, [
               other_user
             ])

    assert {:ok, message2} =
             Bonfire.Messages.send(other_user, %{post_content: %{html_body: "Hello message 2"}}, [
               user
             ])

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/messages")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "ID")
    assert String.contains?(conn.resp_body, "From")
    assert String.contains?(conn.resp_body, "To")

    # Verify message content is in the export
    assert String.contains?(conn.resp_body, "Hello message 1")
    assert String.contains?(conn.resp_body, "Hello message 2")

    # Verify usernames are in the export
    user_username = e(user, :character, :username, nil)
    other_username = e(other_user, :character, :username, nil)
    assert String.contains?(conn.resp_body, user_username)
    assert String.contains?(conn.resp_body, other_username)
  end

  test "export silenced works", %{user: user, conn: conn} do
    # Create a user to silence
    silenced_user = fake_user!("SilencedUser")

    # Silence the user
    assert {:ok, _} = Bonfire.Boundaries.Blocks.block(silenced_user, :silence, current_user: user)

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/silenced")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "Account address")

    flood(conn.resp_body, "exported")
    # Verify silenced user is in the export
    silenced_username = Bonfire.Me.Characters.display_username(silenced_user, true)

    msg =
      "Expected silenced username #{silenced_username} to be in the export, but found #{conn.resp_body}"

    assert String.contains?(conn.resp_body, silenced_username), msg
  end

  test "export ghosted works", %{user: user, conn: conn} do
    # Create a user to ghost
    ghosted_user = fake_user!("GhostedUser")

    # Ghost the user
    assert {:ok, _} = Bonfire.Boundaries.Blocks.block(ghosted_user, :ghost, current_user: user)

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/csv/ghosted")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]
    assert String.contains?(conn.resp_body, "Account address")

    # Verify ghosted user is in the export
    ghosted_username = Bonfire.Me.Characters.display_username(ghosted_user, true)

    msg =
      "Expected ghosted username #{ghosted_username} to be in the export, but found #{conn.resp_body}"

    assert String.contains?(conn.resp_body, ghosted_username), msg
  end

  test "export profile JSON works", %{user: user, conn: conn} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/json/actor")

    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    # Should be valid JSON
    assert {:ok, decoded} = Jason.decode(conn.resp_body)

    # Verify it contains expected ActivityPub actor fields
    assert Map.has_key?(decoded, "type")
    assert Map.has_key?(decoded, "id")
    assert Map.has_key?(decoded, "preferredUsername")
    assert decoded["preferredUsername"] == e(user, :character, :username, nil)
  end

  test "export keys works", %{user: user, conn: conn} do
    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/binary/keys/asc")

    assert conn.status == 200
    assert is_binary(conn.resp_body |> flood("exported"))

    # Check that it looks like a valid key export
    assert String.contains?(conn.resp_body, "BEGIN")
    assert String.contains?(conn.resp_body, "END")
    # Should contain both private and public keys
    assert String.length(conn.resp_body) > 100
  end

  # Note: Outbox export is currently commented out in the UI due to performance concerns
  test "export outbox JSON works", %{user: user, conn: conn} do
    assert {:ok, post1} =
             Bonfire.Posts.publish(
               current_user: user,
               boundary: "public",
               post_attrs: %{post_content: %{html_body: "Test post 1 content"}}
             )

    # Test export via controller
    conn =
      conn
      |> assign(:current_user, user)
      |> get("/settings/export/json/outbox")

    assert conn.status == 200
    assert ["application/json" <> _] = get_resp_header(conn, "content-type")

    # Should be valid JSON
    assert {:ok, decoded} = Jason.decode(conn.resp_body)

    # should contain our post
    assert String.contains?(conn.resp_body, "Test post 1 content")

    # Check that it looks like an outbox/collection
    assert Map.has_key?(decoded, "type")
    assert decoded["type"] == "OrderedCollection"
    assert Map.has_key?(decoded, "orderedItems")
    assert is_list(decoded["orderedItems"])

    # Should contain the post (as ActivityPub Create activity)
    activities = decoded["orderedItems"]
    assert length(activities) > 0
    flood(activities, "json activities")

    # FIXME: we're getting objects instead of activities
    # check we have a Create activity that contains our post content
    create_activity =
      Enum.find(activities, fn item ->
        is_map(item) and
          item["type"] == "Create" and
          is_map(item["object"]) and
          String.contains?(to_string(item["object"]["content"] || ""), "Test post 1 content")
      end)

    assert create_activity, "Should contain a Create activity with our post content"

    # FIXME: we're getting repeats?
    assert length(activities) == 1
  end
end
