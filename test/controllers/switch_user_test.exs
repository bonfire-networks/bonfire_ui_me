defmodule Bonfire.UI.Me.SwitchUserController.Test do
  use Bonfire.UI.Me.ConnCase, async: true
  alias Bonfire.Me.Fake

  describe "index" do
    test "not logged in" do
      conn = conn()
      conn = get(conn, "/switch-user")
      assert redirected_to(conn) =~ "/login"
    end

    test "no users" do
      account = fake_account!()
      conn = conn(account: account)
      conn = get(conn, "/switch-user")
      assert redirected_to(conn) == "/create-user"
    end

    test "shows account's users" do
      account = fake_account!()
      alice = fake_user!(account)
      bob = fake_user!(account)
      conn = conn(account: account)
      conn = get(conn, "/switch-user")
      doc = floki_response(conn)
      [a, b] = Floki.find(doc, ".component_user_preview")
      assert Floki.text(a) =~ "@#{alice.character.username}"
      assert Floki.text(b) =~ "@#{bob.character.username}"
    end
  end

  describe "show" do
    test "not logged in" do
      conn = conn()
      conn = get(conn, "/switch-user/#{username()}")
      assert redirected_to(conn) =~ "/login"
    end

    test "not found" do
      account = fake_account!()
      _user = fake_user!(account)
      conn = conn(account: account)
      conn = get(conn, "/switch-user/#{username()}")
      assert redirected_to(conn) == "/switch-user"
    end

    test "not permitted" do
      alice = fake_account!()
      bob = fake_account!()
      _alice_user = fake_user!(alice)
      bob_user = fake_user!(bob)
      conn = conn(account: alice)
      conn = get(conn, "/switch-user/#{bob_user.character.username}")
      assert redirected_to(conn) == "/switch-user"
      conn = get(recycle(conn), "/switch-user")
      # doc = floki_response(conn)
      # assert [err] = find_flash(doc)
      # assert_flash_kind(err, :error)
    end

    test "success" do
      account = fake_account!()

      user =
        fake_user!(account, %{name: "tester"})
        |> repo().preload([:character, :profile])

      conn = conn(account: account)
      conn = get(conn, "/switch-user/#{user.character.username}")
      next = redirected_to(conn)
      assert next == "/"
      conn = get(conn, "/dashboard")
      assert get_session(conn, :current_user_id) == user.id
      doc = floki_response(conn)
      # debug(doc)
      [a] = Floki.find(doc, "[data-id='user_dashboard']")
      # assert [info] = find_flash(doc)
      # assert_flash(info, :info, "Welcome back, tester!")
    end
  end
end
