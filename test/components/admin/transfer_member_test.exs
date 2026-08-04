defmodule Bonfire.UI.Me.TransferMemberTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  alias Bonfire.Me.Users

  test "an admin can transfer a member's profile to another account (by @username)" do
    admin_account = fake_account!()
    admin = fake_admin!(admin_account)

    source_account = fake_account!()
    member = fake_user!(source_account)

    # scope to this member's transfer modal so other listed users (e.g. the admin, system actors) don't clash
    modal =
      "#" <>
        Bonfire.UI.Common.deterministic_dom_id(
          Bonfire.UI.Me.MemberLive,
          member.id,
          "transfer-user",
          nil
        )

    conn(user: admin, account: admin_account)
    |> visit("/settings/instance/members")
    |> wait_async()
    # open THIS member's modal (renders its form into the modal singleton)
    |> within(modal, fn session ->
      click_button(session, "[data-role=open_modal]", "Transfer to another account")
    end)
    # the form now lives in the singleton — fill + submit
    |> fill_in("Email or @username of the destination account",
      with: "@#{admin.character.username}"
    )
    |> click_button("Transfer profile")
    |> assert_has("[role=alert]", text: "transferred")

    # the profile now belongs to the admin's account, not the source
    assert Enum.any?(Users.by_account(admin_account), &(&1.id == member.id))
    refute Enum.any?(Users.by_account(source_account), &(&1.id == member.id))
  end
end
