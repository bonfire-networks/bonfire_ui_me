defmodule Bonfire.UI.Me.ProfileNameSurfacesTest do
  @moduledoc """
  A display name is plain text. Wherever it is shown (profile page, profile card, a feed row, a notification, the person picker) it is escaped: markup in a name is never live, and a name like `<3 Ana` shows as that text.
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  @payload "&lt;img src=x onerror=alert(1)&gt;"
  @heart "<3 Ana"

  setup do
    account = fake_account!()
    owner = fake_user!(account)
    viewer_account = fake_account!()
    viewer = fake_user!(viewer_account)

    %{
      owner: owner,
      viewer: viewer,
      conn: conn(user: viewer, account: viewer_account)
    }
  end

  defp rename!(user, name) do
    {:ok, user} = Bonfire.Me.Users.update(user, %{"profile" => %{"name" => name}})
    repo().preload(user, [:profile, :character], force: true)
  end

  # `owner` answers a post by `viewer`, so the reply shows in the viewer's notifications
  defp reply_to_viewer(owner, viewer) do
    {:ok, original} =
      Bonfire.Posts.publish(
        current_user: viewer,
        post_attrs: %{post_content: %{html_body: "the original post"}},
        boundary: "public"
      )

    {:ok, reply} =
      Bonfire.Posts.publish(
        current_user: owner,
        post_attrs: %{
          post_content: %{html_body: "@#{viewer.character.username} hello there"},
          reply_to_id: original.id
        },
        boundary: "public"
      )

    reply
  end

  defp card(owner) do
    render_component(&Bonfire.UI.Me.ProfileItemLive.render/1, %{
      profile: owner.profile,
      character: owner.character,
      __context__: %{}
    })
    |> Floki.parse_fragment!()
  end

  defp picker(person) do
    render_component(Bonfire.UI.Common.BasicMultiselectLive,
      id: "name-surfaces-picker",
      form_input_name: "to",
      preloaded_options:
        Bonfire.UI.Common.MultiselectLive.UserSelectorLive.load_users(
          person,
          Bonfire.Data.Identity.User
        ),
      selected_options: [{person.profile.name, person.id}],
      __context__: %{current_user: person, current_user_id: person.id}
    )
    |> Floki.parse_fragment!()
  end

  describe "a name with entity-encoded markup" do
    test "is inert on the profile page, a post by them, a notification and the picker", %{
      owner: owner,
      viewer: viewer,
      conn: conn
    } do
      owner = rename!(owner, @payload)
      post = reply_to_viewer(owner, viewer)

      conn
      |> visit("/@#{owner.character.username}")
      |> wait_async()
      |> refute_has("img[src='x']")
      |> refute_has("[onerror*='alert(1)']")

      conn
      |> visit("/post/#{post.id}")
      |> wait_async()
      |> assert_has("[data-id=main_section]", text: "hello there")
      |> refute_has("img[src='x']")
      |> refute_has("[onerror*='alert(1)']")

      conn
      |> visit("/notifications")
      |> wait_async()
      |> refute_has("img[src='x']")
      |> refute_has("[onerror*='alert(1)']")

      assert Floki.find(card(owner), "img[src=x]") == []
      assert Floki.find(card(owner), "[onerror*='alert(1)']") == []
      assert Floki.find(picker(owner), "img[src=x]") == []
      assert Floki.find(picker(owner), "[onerror*='alert(1)']") == []
    end
  end

  describe "a name with a literal `<3`" do
    test "shows as text on the profile page, a post by them, a notification and the picker", %{
      owner: owner,
      viewer: viewer,
      conn: conn
    } do
      owner = rename!(owner, @heart)
      assert owner.profile.name == @heart
      post = reply_to_viewer(owner, viewer)

      conn
      |> visit("/@#{owner.character.username}")
      |> wait_async()
      |> assert_has("#profile_name_section", text: @heart)

      conn
      |> visit("/post/#{post.id}")
      |> wait_async()
      |> assert_has("[data-id=main_section]", text: @heart)

      conn
      |> visit("/notifications")
      |> wait_async()
      |> assert_has("[data-role=subject]", text: @heart)

      assert card(owner) |> Floki.find("[data-id=profile_name]") |> Floki.text() =~ @heart
      assert picker(owner) |> Floki.text() =~ @heart
      refute picker(owner) |> Floki.text() =~ "&lt;"
    end
  end
end
