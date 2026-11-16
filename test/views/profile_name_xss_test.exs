defmodule Bonfire.UI.Me.ProfileNameXSSTest do
  @moduledoc """
  A display name is text. Whatever markup a person writes into it, as plain tags or as HTML entities, is shown as text, never stored as a live tag and never rendered as one on the profile, on a profile card or in a person picker.
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  @payload "&lt;img src=x onerror=alert(1)&gt;"

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
    # the same call the profile edit form makes
    {:ok, user} = Bonfire.Me.Users.update(user, %{"profile" => %{"name" => name}})
    repo().preload(user, [:profile, :character], force: true)
  end

  defp card(owner) do
    render_component(&Bonfire.UI.Me.ProfileItemLive.render/1, %{
      profile: owner.profile,
      character: owner.character,
      __context__: %{}
    })
    |> Floki.parse_fragment!()
  end

  # the picker as the person selector builds it: `{name, id}` options, the first being the person themself
  defp picker(person) do
    render_component(Bonfire.UI.Common.BasicMultiselectLive,
      id: "name-xss-picker",
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

  test "control: a normal name is stored and shown on the profile", %{
    owner: owner,
    conn: conn
  } do
    owner = rename!(owner, "Ada Lovelace")
    assert owner.profile.name == "Ada Lovelace"

    conn
    |> visit("/@#{owner.character.username}")
    |> wait_async()
    |> assert_has("#profile_name_section", text: "Ada Lovelace")
  end

  test "control: a normal name is shown on the profile card", %{owner: owner} do
    owner = rename!(owner, "Ada Lovelace")

    assert card(owner) |> Floki.find("[data-id=profile_name]") |> Floki.text() =~ "Ada Lovelace"
  end

  test "control: a normal name is shown in the person picker", %{owner: owner} do
    owner = rename!(owner, "Ada Lovelace")

    assert picker(owner) |> Floki.text() =~ "Ada Lovelace"
  end

  test "entity-encoded markup in a name is stored as plain text", %{owner: owner} do
    owner = rename!(owner, @payload)

    # a name is plain text (tags stripped, entities decoded); every place that shows it escapes it
    assert owner.profile.name == "<img src=x onerror=alert(1)>"
  end

  test "entity-encoded markup in a name does not render a live tag on the profile page", %{
    owner: owner,
    conn: conn
  } do
    owner = rename!(owner, @payload)

    conn
    |> visit("/@#{owner.character.username}")
    |> wait_async()
    |> refute_has("img[src='x']")
    |> refute_has("[onerror*='alert(1)']")
  end

  test "entity-encoded markup in a name does not render a live tag on the profile card", %{
    owner: owner
  } do
    owner = rename!(owner, @payload)

    assert Floki.find(card(owner), "img[src=x]") == []

    # the avatar image has its own fixed fallback `onerror`; only a handler carrying the payload is a hole
    assert Floki.find(card(owner), "[onerror*='alert(1)']") == []
  end

  test "entity-encoded markup in a name does not render a live tag in the person picker", %{
    owner: owner
  } do
    owner = rename!(owner, @payload)

    assert Floki.find(picker(owner), "img[src=x]") == []
    assert Floki.find(picker(owner), "[onerror]") == []
  end
end
