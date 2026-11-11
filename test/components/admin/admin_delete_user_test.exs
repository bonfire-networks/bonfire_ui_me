defmodule Bonfire.UI.Me.AdminDeleteUserTest do
  @moduledoc "An admin deletes a user (this profile, or the whole account) from the members pages, once the user is blocked instance-wide and behind the sudo gate."
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Boundaries.Blocks

  setup do
    account = fake_account!()
    admin = fake_admin!(account)
    {:ok, account: account, admin: admin, conn: conn(user: admin, account: account)}
  end

  defp enqueued_ids do
    Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    |> Enum.flat_map(& &1.args["ids"])
  end

  defp block!(user) do
    {:ok, _} = Blocks.block(user, :block, scope: :instance_wide)
    user
  end

  defp remote_user! do
    Tesla.Mock.mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)
    Process.put(:federating, true)

    # creating the remote actor goes through ActivityPub's fetcher, which reads Application env rather than the process
    instance_config = Application.get_env(:activity_pub, :instance)
    Application.put_env(:activity_pub, :instance, Keyword.put(instance_config, :federating, true))
    on_exit(fn -> Application.put_env(:activity_pub, :instance, instance_config) end)

    {:ok, remote} = Bonfire.Federate.ActivityPub.Simulate.fake_remote_user()
    remote
  end

  # opens the row's "Delete user & data" modal; its content renders in the page's modal singleton
  defp open_delete_modal(session, user) do
    modal =
      "#" <>
        Bonfire.UI.Common.deterministic_dom_id(
          Bonfire.UI.Me.MemberLive,
          user.id,
          "delete-user",
          nil
        )

    session
    |> wait_async()
    |> within(modal, fn session ->
      click_button(session, "[data-role=open_modal]", "Delete user & data")
    end)
    |> wait_async()
  end

  defp through_sudo(session, account, title) do
    session
    |> assert_has("#sudo-password-form")
    |> fill_in("Your password", with: account.credential.password)
    |> click_button("#sudo-password-submit", "Verify and continue")
    |> assert_has("#sudo-title", text: title)
  end

  test "a blocked remote user: the modal offers only this profile, and confirming queues it", %{
    conn: conn,
    account: account
  } do
    remote = remote_user!() |> block!()

    conn
    |> visit("/settings/instance/remote_users")
    |> open_delete_modal(remote)
    |> assert_has("#delete-profile-link", text: "Delete this profile")
    |> refute_has("#delete-account-link")
    |> click_link("#delete-profile-link", "Delete this profile")
    |> through_sudo(account, "Delete this user")
    |> assert_has("p.prose", text: remote.character.username)
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Profile deletion requested")
    # back to the tab the delete started from, through the password step
    |> assert_has("a#sudo-done-go[href='/settings/instance/remote_users']")

    assert remote.id in enqueued_ids()
  end

  test "a blocked local user: the modal offers both, and this profile leaves the account", %{
    conn: conn,
    account: account
  } do
    target_account = fake_account!()
    sibling = fake_user!(target_account)
    target = fake_user!(target_account) |> block!()

    conn
    |> visit("/settings/instance/members")
    |> open_delete_modal(target)
    |> assert_has("#delete-profile-link", text: "Delete this profile")
    # |> assert_has("#delete-account-link", text: "Delete the whole account")
    |> assert_has("#delete-account-link", text: "Delete their")
    |> click_link("#delete-profile-link", "Delete this profile")
    |> through_sudo(account, "Delete this user")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Profile deletion requested")
    |> assert_has("a#sudo-done-go[href='/settings/instance/members']")

    ids = enqueued_ids()
    assert target.id in ids
    refute sibling.id in ids
    refute target_account.id in ids
  end

  test "a blocked local user: the whole account path counts the profiles and deletes them all", %{
    conn: conn,
    account: account
  } do
    target_account = fake_account!()
    sibling = fake_user!(target_account)
    target = fake_user!(target_account) |> block!()

    conn
    |> visit("/settings/instance/members")
    |> open_delete_modal(target)
    |> assert_has("#delete-account-link", text: "2 profiles")
    # |> click_link("#delete-account-link", "Delete the whole account")
    |> click_link("#delete-account-link", "Delete their")
    |> through_sudo(account, "Delete this account")
    |> assert_has("p.prose", text: "2 profiles")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Account deletion requested")

    ids = enqueued_ids()
    assert target_account.id in ids
    assert target.id in ids
    assert sibling.id in ids
  end

  test "a blocked user who is an admin: the modal says to revoke their admin role first, with no delete links",
       %{conn: conn} do
    target = fake_admin!(fake_account!()) |> block!()

    conn
    |> visit("/settings/instance/members")
    |> open_delete_modal(target)
    # |> assert_has("[data-role=delete_user_admin_first]", text: "revoke their admin role first")
    |> assert_has("[data-role=delete_user_admin_first]", text: "revoke their admin role")
    |> refute_has("#delete-profile-link")
    |> refute_has("#delete-account-link")
  end

  test "a user who isn't blocked: the modal explains and has no delete buttons", %{conn: conn} do
    local = fake_user!(fake_account!())

    conn
    |> visit("/settings/instance/members")
    |> open_delete_modal(local)
    |> assert_has("[data-role=delete_user_blocked_first]", text: "Block this user instance-wide")
    |> refute_has("#delete-profile-link")
    |> refute_has("#delete-account-link")
  end

  test "a remote user who isn't blocked: the modal explains and has no delete buttons", %{
    conn: conn
  } do
    remote = remote_user!()

    conn
    |> visit("/settings/instance/remote_users")
    |> open_delete_modal(remote)
    |> assert_has("[data-role=delete_user_blocked_first]", text: "Block this user instance-wide")
    |> refute_has("#delete-profile-link")
    |> refute_has("#delete-account-link")
  end
end
