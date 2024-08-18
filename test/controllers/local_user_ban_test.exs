defmodule Bonfire.UI.Me.Boundaries.InstanceWideGhostActorTest do
  use Bonfire.UI.Me.ConnCase, async: true
  # import Bonfire.Boundaries.Debug
  alias ActivityPub.Config

  test "instance-wide ghosted local user cannot switch to that or any other identity" do
    bob = fake_account!()
    alice_user = fake_user!(bob)
    bob_user = fake_user!(bob)
    Bonfire.Boundaries.Blocks.block(bob_user, :ghost, :instance_wide)

    conn = conn(account: bob)
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
