defmodule Bonfire.UI.Me.CreateUserController.Test do
  use Bonfire.UI.Me.ConnCase, async: true

  test "form renders" do
    alice = fake_account!()
    conn = conn(account: alice)
    conn = get(conn, "/create-user")
    doc = floki_response(conn)
    view = Floki.find(doc, "#create_user")
    assert [form] = Floki.find(doc, "#create-user-form")
    assert [_] = Floki.find(form, "#create-form_character_username")
    assert [_] = Floki.find(form, "#create-form_profile_name")
    assert [_] = Floki.find(form, "#create-form_profile_summary")
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  describe "required fields" do
    test "missing all" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = post(conn, "/create-user", %{"user" => %{}})
      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")
      assert [_] = Floki.find(form, "#create-form_character_username")

      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      assert [_] = Floki.find(form, "#create-form_profile_name")
      # assert_field_error(form, "create-form_profile_name", ~r/can't be blank/)
      assert [_] = Floki.find(form, "#create-form_profile_summary")

      # assert_field_error(form, "create-form_profile_summary", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "with name" do
      alice = fake_account!()
      conn = conn(account: alice)

      conn =
        post(conn, "/create-user", %{
          "user" => %{"profile" => %{"name" => name()}}
        })

      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")
      assert_field_good(form, "create-form_profile_name")

      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      # assert_field_error(form, "create-form_profile_summary", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "with summary" do
      alice = fake_account!()
      conn = conn(account: alice)

      conn =
        post(conn, "/create-user", %{
          "user" => %{"profile" => %{"summary" => summary()}}
        })

      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")
      assert_field_good(form, "create-form_profile_summary")

      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      # assert_field_error(form, "create-form_profile_name", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing username" do
      alice = fake_account!()
      conn = conn(account: alice)

      conn =
        post(conn, "/create-user", %{
          "user" => %{"profile" => %{"summary" => summary(), "name" => name()}}
        })

      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")
      assert_field_good(form, "create-form_profile_summary")
      assert_field_good(form, "create-form_profile_name")

      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing name" do
      alice = fake_account!()
      conn = conn(account: alice)

      conn =
        post(conn, "/create-user", %{
          "user" => %{
            "profile" => %{"summary" => summary()},
            "character" => %{"username" => username()}
          }
        })

      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")
      assert_field_good(form, "create-form_profile_summary")
      assert_field_good(form, "create-form_character_username")
      # assert_field_error(form, "create-form_profile_name", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end
  end

  test "username taken" do
    alice = fake_account!()
    user = fake_user!(alice)
    conn = conn(account: alice)

    params = %{
      "user" => %{
        "profile" => %{"summary" => summary(), "name" => name()},
        "character" => %{"username" => user.character.username}
      }
    }

    conn = post(conn, "/create-user", params)
    doc = floki_response(conn)
    assert [view] = Floki.find(doc, "#create_user")
    assert Floki.text(view) =~ "already been taken"
    assert [form] = Floki.find(doc, "#create-user-form")
    assert_field_good(form, "create-form_profile_summary")
    assert_field_good(form, "create-form_profile_name")

    # assert_field_error(form, "create-form_character_username", ~r/has already been taken/)
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  test "successfully create first user" do
    alice = fake_account!()
    conn = conn(account: alice)
    username = username()

    params = %{
      "user" => %{
        "profile" => %{"summary" => summary(), "name" => name()},
        "character" => %{"username" => username}
      }
    }

    conn = post(conn, "/create-user", params)
    # assert_raise RuntimeError, debug(floki_response(conn))
    assert redirected_to(conn) == "/"
    conn = get(recycle(conn), "/")
    doc = floki_response(conn)
    assert [ok] = find_flash(doc)
    assert_flash(ok, :info, ~r/nice/)
  end

  test "successfully sets privacy options" do
    alice = fake_account!()
    conn = conn(account: alice)
    username = username()

    params = %{
      "user" => %{
        "profile" => %{"summary" => summary(), "name" => name()},
        "character" => %{"username" => username}
      },
      "undiscoverable" => "true",
      "unindexable" => "true"
    }

    conn = post(conn, "/create-user", params)
    # assert_raise RuntimeError, debug(floki_response(conn))
    assert redirected_to(conn) == "/"
    conn = get(recycle(conn), "/")
    doc = floki_response(conn)
    assert [ok] = find_flash(doc)
    assert_flash(ok, :info, ~r/nice/)

    {:ok, user} =
      Bonfire.Me.Users.by_username(username)
      |> repo().maybe_preload(:settings)

    assert Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], nil,
             current_user: user
           ) == true

    assert Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, user) == false
  end
end
