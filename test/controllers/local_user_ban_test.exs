defmodule Bonfire.UI.Me.Boundaries.InstanceWideGhostActorTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  # import Bonfire.Boundaries.Debug
  alias ActivityPub.Config

  test "instance-wide blocking a user via live handler sets force_logout cache flag" do
    target_account = fake_account!()
    target_user = fake_user!(target_account)

    admin_account = fake_account!()
    admin = fake_admin!(admin_account)
    admin_conn = conn(user: admin, account: admin_account)

    {:ok, view, _html} = live(admin_conn, "/@#{target_user.character.username}")

    render_click(view, "Bonfire.Boundaries.Blocks:block_instance_wide", %{
      "id" => target_user.id
    })

    assert Bonfire.Common.Cache.get!("force_logout:#{target_user.id}") == true
  end

  test "force_logout_account causes HTTP plug to clear session and return nil current_user" do
    target_account = fake_account!()
    target_user = fake_user!(target_account)

    conn = conn(user: target_user, account: target_account)

    # Sanity check: user is present before force-logout
    assert get(conn, "/dashboard").assigns[:current_user]

    Bonfire.Me.Users.LiveHandler.force_logout_account(target_account.id)

    assert Bonfire.Common.Cache.get!("force_logout:#{target_user.id}") == true

    # Plug should now reject the session
    conn = get(conn, "/dashboard")
    refute conn.assigns[:current_user]
  end

  test "instance-wide ghosted local user cannot switch to that or any other identity" do
    account = fake_account!()
    alice_user = fake_user!(account)
    bob_user = fake_user!(account)
    Bonfire.Boundaries.Blocks.block(bob_user, :ghost, :instance_wide)

    conn = conn(account: account)
    assert catch_throw(get(conn, "/switch-user/#{bob_user.character.username}"))

    assert catch_throw(get(conn, "/switch-user/#{alice_user.character.username}"))

    # assert redirected_to(conn) == "/switch-user"
    # assert catch_throw(get(recycle(conn), "/switch-user") |> warn("swwww"))
    conn = get(recycle(conn), "/switch-user")
    # doc = floki_response(conn)
    assert redirected_to(conn) == "/login"
    # conn = get(recycle(conn), "/error")
    # doc = floki_response(conn)
    # assert [err] = find_flash(doc)
    # assert_flash_kind(err, :error)
  end
end
