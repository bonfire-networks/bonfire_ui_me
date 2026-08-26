defmodule Bonfire.UI.Me.SwitchUserController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

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
      user_previews = Floki.find(doc, ".component_user_preview")
      assert length(user_previews) == 2
      all_text = user_previews |> Enum.map(&Floki.text/1) |> Enum.join(" ")
      assert all_text =~ alice.profile.name
      assert all_text =~ bob.profile.name
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
      assert [_] = Floki.find(doc, "[data-id='user_dashboard']")
    end

    # Logging straight into a profile records a per-profile last-seen (see `Accounts.login/2`), so reaching one by switching has to record it too. Otherwise a profile someone uses daily, but
    # always arrives at by switching, looks like it has never been used.
    test "records last-seen for the profile switched to" do
      account = fake_account!()
      user = fake_user!(account) |> repo().preload([:character])

      refute Bonfire.Social.Seen.last_date(account, user),
             "nothing should be recorded before the switch"

      conn = conn(account: account)
      conn = get(conn, "/switch-user/#{user.character.username}")
      assert redirected_to(conn) == "/"

      assert %DateTime{} = seen_at = Bonfire.Social.Seen.last_date(account, user)
      assert DateTime.to_date(seen_at) == Date.utc_today()
    end
  end
end
