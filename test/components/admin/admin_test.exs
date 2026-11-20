defmodule Bonfire.UI.Me.AdminTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  import Ecto.Query

  alias Bonfire.Data.AccessControl.Encircle
  alias Bonfire.Boundaries.Scaffold.Instance

  # read from the database: the `alice` of a test is the struct from before the click
  defp in_circle?(user, circle_id) do
    Bonfire.Common.Repo.exists?(
      from(e in Encircle, where: e.subject_id == ^user.id and e.circle_id == ^circle_id)
    )
  end

  defp admin?(user), do: in_circle?(user, Instance.admin_circle())
  defp moderator?(user), do: in_circle?(user, Instance.mod_circle())

  defp admin_on_profile_of(user) do
    account = fake_account!()
    admin = fake_admin!(account)

    conn(user: admin, account: account)
    |> visit("/@#{user.character.username}")
  end

  # the admin menu opens a confirmation, as for the other privileged actions (a transfer of a profile, a deletion), and the action runs on confirming
  test "As an admin I want to make another user admin, after confirming" do
    alice = fake_user!(fake_account!())

    admin_on_profile_of(alice)
    |> click_button("[data-role=open_modal]", "Make admin")
    |> click_button("Make them an admin")
    |> assert_has("[role=alert]", text: "They are now an admin!")

    assert admin?(alice)
    # an admin is not a moderator unless asked
    refute moderator?(alice)
  end

  test "As an admin I can revoke another admin's powers, after confirming" do
    other_admin = fake_admin!(fake_account!())
    # prove the positive first
    assert admin?(other_admin)

    admin_on_profile_of(other_admin)
    |> click_button("[data-role=open_modal]", "Revoke admin")
    |> click_button("Revoke their admin powers")
    |> assert_has("[role=alert]", text: "They are no longer an admin.")

    refute admin?(other_admin)
  end

  defp as_admin_visit(path) do
    account = fake_account!()
    admin = fake_admin!(account)

    conn(user: admin, account: account)
    |> visit(path)
    |> wait_async()
  end

  # opens the row's make or revoke confirmation; its content renders in the page's modal singleton
  defp open_admin_role_modal(session, user, action, label, parent_id \\ nil) do
    opener =
      "#" <>
        Bonfire.UI.Common.deterministic_dom_id(
          Bonfire.UI.Me.AdminRoleLive,
          user.id,
          action,
          parent_id
        )

    session
    |> within(opener, fn session -> click_button(session, "[data-role=open_modal]", label) end)
    |> wait_async()
  end

  # the picked person arrives as the JSON the member search puts in the form
  defp pick_in_admins_search(session, user) do
    session
    |> PhoenixTest.unwrap(fn view ->
      view
      |> with_target("#circle_members")
      |> render_hook("change", %{
        "_target" => ["multi_select", "add_to_circles"],
        "multi_select" => %{
          "add_to_circles" =>
            Jason.encode!(%{
              "id" => user.id,
              "name" => user.profile.name,
              "username" => user.character.username,
              "type" => "user"
            })
        }
      })
    end)
    |> wait_async()
  end

  test "As an admin I can make a member an admin from the members list" do
    alice = fake_user!(fake_account!())

    as_admin_visit("/settings/instance/members")
    |> open_admin_role_modal(alice, "make-admin", "Make admin")
    |> click_button("Make them an admin")
    |> assert_has("[role=alert]", text: "They are now an admin!")

    assert admin?(alice)
  end

  test "As an admin I can revoke an admin from the members list" do
    other_admin = fake_admin!(fake_account!())
    # prove the positive first
    assert admin?(other_admin)

    as_admin_visit("/settings/instance/members")
    |> open_admin_role_modal(other_admin, "revoke-admin", "Revoke admin")
    |> click_button("Revoke their admin powers")
    |> assert_has("[role=alert]", text: "They are no longer an admin.")

    refute admin?(other_admin)
  end

  test "As an admin I can pick someone in the admins page search and make them an admin, after confirming" do
    alice = fake_user!(fake_account!())

    session =
      as_admin_visit("/settings/instance/admins")
      |> pick_in_admins_search(alice)
      |> assert_has("button", text: "Make them an admin")

    # picking only opens the confirmation
    refute admin?(alice)
    refute_has(session, "#circle_members #member-#{alice.id}")

    session
    |> click_button("Make them an admin")
    |> assert_has("[role=alert]", text: "They are now an admin!")
    # the list shows them without a reload
    |> assert_has("#circle_members #member-#{alice.id}")

    assert admin?(alice)
  end

  test "As an admin I can revoke an admin from the admins page" do
    other_admin = fake_admin!(fake_account!())
    assert admin?(other_admin)

    as_admin_visit("/settings/instance/admins")
    |> assert_has("#circle_members #member-#{other_admin.id}")
    |> open_admin_role_modal(other_admin, "revoke-admin", "Revoke admin", "admin_circle")
    |> click_button("Revoke their admin powers")
    |> assert_has("[role=alert]", text: "They are no longer an admin.")
    # the list drops them without a reload
    |> refute_has("#circle_members #member-#{other_admin.id}")

    refute admin?(other_admin)
  end

  # the browser can send both events directly, so the server has to refuse them
  test "A non-admin's pick on the admins page makes no one an admin" do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(fake_account!())

    conn(user: me, account: account)
    |> visit("/settings/instance/admins")
    |> wait_async()
    |> pick_in_admins_search(alice)
    |> PhoenixTest.unwrap(fn view ->
      render_hook(view, "Bonfire.Me.Users:make_admin", %{"username_or_id" => alice.id})
    end)

    refute admin?(alice)
  end

  # the admin circle also shows on the generic circle pages: a non-admin can't load it as its caretaker there (settings), or may not edit it (circle page), so neither offers them its search
  test "Only admins see the search to make someone an admin, wherever the admin circle is listed" do
    path = "/settings/boundaries/circle/#{Instance.admin_circle()}"

    # prove the positive first: an admin gets the search there
    as_admin_visit(path)
    |> assert_has("#circle_members #add_members")

    account = fake_account!()
    me = fake_user!(account)

    for path <- [path, "/circle/#{Instance.admin_circle()}/members"] do
      conn(user: me, account: account)
      |> visit(path)
      |> wait_async()
      |> refute_has("#add_members")
    end
  end

  defp suggested?(user), do: in_circle?(user, Instance.suggested_profiles_circle())

  defp moderator_conn do
    account = fake_account!()

    {:ok, moderator} =
      Bonfire.Me.Users.make_moderator(fake_user!(account), skip_boundary_check: true)

    conn(user: moderator, account: account)
  end

  test "As an admin I can add someone to Suggested Profiles from its page, and remove them" do
    alice = fake_user!(fake_account!())

    session =
      as_admin_visit("/settings/instance/suggested_profiles")
      |> assert_has("#circle_members #add_members")
      |> pick_in_admins_search(alice)
      |> assert_has("[role=alert]", text: "Added to circle!")
      |> assert_has("#circle_members", text: alice.profile.name)

    assert suggested?(alice)

    session
    |> click_button("[data-role=remove_user]", "Remove")
    |> refute_has("#circle_members", text: alice.profile.name)

    refute suggested?(alice)
  end

  # the page offers its search to moderators too (`:mediate` on the instance), and the circle is controlled by the `mods_may_manage` preset
  test "As a moderator I can add someone to Suggested Profiles from its page" do
    alice = fake_user!(fake_account!())

    moderator_conn()
    |> visit("/settings/instance/suggested_profiles")
    |> wait_async()
    |> assert_has("#circle_members #add_members")
    |> pick_in_admins_search(alice)
    |> assert_has("[role=alert]", text: "Added to circle!")

    assert suggested?(alice)
  end

  test "As an admin I can make someone a moderator from the moderators page, and remove them" do
    alice = fake_user!(fake_account!())

    session =
      as_admin_visit("/settings/instance/mods")
      |> assert_has("#circle_members #add_members")
      |> pick_in_admins_search(alice)
      |> assert_has("#circle_members", text: alice.profile.name)

    assert moderator?(alice)

    session
    |> click_button("[data-role=remove_user]", "Remove")
    |> refute_has("#circle_members", text: alice.profile.name)

    refute moderator?(alice)
  end

  # the browser can send the pick without the search showing, so the server has to refuse it
  test "Someone who is not an admin nor a moderator changes neither Suggested Profiles nor the moderators" do
    account = fake_account!()
    me = fake_user!(account)
    alice = fake_user!(fake_account!())

    for tab <- ["suggested_profiles", "mods"] do
      conn(user: me, account: account)
      |> visit("/settings/instance/#{tab}")
      |> wait_async()
      |> refute_has("#add_members")
      |> pick_in_admins_search(alice)
    end

    refute suggested?(alice)
    refute moderator?(alice)
  end

  test "As an admin I can make them a moderator too, from the same confirmation" do
    alice = fake_user!(fake_account!())

    admin_on_profile_of(alice)
    |> click_button("[data-role=open_modal]", "Make admin")
    |> check("Also declare them as an instance moderator")
    |> click_button("Make them an admin")
    |> assert_has("[role=alert]", text: "They are now an admin!")

    assert admin?(alice)
    assert moderator?(alice)
  end
end
