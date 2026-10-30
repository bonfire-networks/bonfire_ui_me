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
