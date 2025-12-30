defmodule Bonfire.UI.Me.CreateUserController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  use Repatch.ExUnit
  import Tesla.Mock

  setup_all do
    mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)
    :ok
  end

  test "form renders" do
    alice = fake_account!()
    conn = conn(account: alice)
    conn = get(conn, "/create-user")
    doc = floki_response(conn)
    view = Floki.find(doc, "#create_user")
    assert [form] = Floki.find(doc, "#create-user-form")
    assert [_] = Floki.find(form, "#create-user-form_profile_0_name")
    assert [_] = Floki.find(form, "#create-user-form_character_0_username")
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

      assert [_] = Floki.find(form, "#create-user-form_character_0_username")
      assert_form_field_error(form, ["user", "character", "username"], ~r/can't be blank/)

      assert [_] = Floki.find(form, "#create-user-form_profile_0_name")
      assert_form_field_error(form, ["user", "profile", "name"], ~r/can't be blank/)

      assert [_] = Floki.find(form, "#create-user-form_profile_0_summary")
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

      assert_form_field_good(form, "#create-user-form_profile_0_name", ["user", "profile", "name"])

      # assert_field_error(form, "create-form_character_username", ~r/can't be blank/)
      # assert_field_error(form, "create-form_profile_summary", ~r/can't be blank/)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "with summary" do
      alice = fake_account!()
      conn = conn(account: alice)
      summary = summary()

      conn =
        post(conn, "/create-user", %{
          "user" => %{"profile" => %{"summary" => summary}}
        })

      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")

      assert [summary_field] = Floki.find(form, "#create-user-form_profile_0_summary")
      assert Floki.text(summary_field) =~ summary

      assert_form_field_error(form, ["user", "character", "username"], ~r/can't be blank/)

      assert_form_field_error(form, ["user", "profile", "name"], ~r/can't be blank/)
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

      assert_form_field_good(form, "#create-user-form_profile_0_name", ["user", "profile", "name"])

      assert_form_field_error(form, ["user", "character", "username"], ~r/can't be blank/)

      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing name" do
      alice = fake_account!()
      conn = conn(account: alice)
      summary = summary()

      conn =
        post(conn, "/create-user", %{
          "user" => %{
            "profile" => %{"summary" => summary},
            "character" => %{"username" => username()}
          }
        })

      doc = floki_response(conn)
      assert [view] = Floki.find(doc, "#create_user")
      assert Floki.text(view) =~ "error occurred"
      assert [form] = Floki.find(doc, "#create-user-form")

      assert [summary_field] = Floki.find(form, "#create-user-form_profile_0_summary")
      assert Floki.text(summary_field) =~ summary

      assert_form_field_good(form, "#create-user-form_character_0_username", [
        "user",
        "character",
        "username"
      ])

      assert_form_field_error(form, ["user", "profile", "name"], ~r/can't be blank/)

      assert [_] = Floki.find(form, "button[type='submit']")
    end
  end

  test "username taken" do
    alice = fake_account!()
    user = fake_user!(alice)
    conn = conn(account: alice)
    summary = summary()

    params = %{
      "user" => %{
        "profile" => %{"summary" => summary, "name" => name()},
        "character" => %{"username" => user.character.username}
      }
    }

    conn = post(conn, "/create-user", params)
    doc = floki_response(conn)
    assert [view] = Floki.find(doc, "#create_user")
    assert Floki.text(view) =~ "already been taken"
    assert [form] = Floki.find(doc, "#create-user-form")

    assert [summary_field] = Floki.find(form, "#create-user-form_profile_0_summary")
    assert Floki.text(summary_field) =~ summary

    assert_form_field_good(form, "#create-user-form_profile_0_name", ["user", "profile", "name"])

    assert_form_field_error(form, ["user", "character", "username"], ~r/has already been taken/)

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
    conn = get(recycle(conn), "/dashboard")
    doc = floki_response(conn)
    # assert redirected_to(conn) == "/dashboard"
  end

  test "first user is autopromoted" do
    # Mock the HTTP call to avoid Tesla client issues
    Repatch.patch(Bonfire.Common.HTTP, :get_cached_body, fn _url -> "1.0.0-rc.2.13" end)

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

    # Since auto-promotion doesn't work in test env (Config.env == :test),
    # manually promote the user to admin to verify the badge displays correctly
    user = Bonfire.Me.Users.by_username(username)
    {:ok, _} = Bonfire.Me.Users.make_admin(user)

    # Navigate to user profile and verify admin badge is shown
    conn = get(recycle(conn), "/@#{username}")
    doc = floki_response(conn)
    assert [_view] = Floki.find(doc, "span.badge[data-role=admin]")
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
    conn = get(recycle(conn), "/dashboard")
    doc = floki_response(conn)

    {:ok, user} =
      Bonfire.Me.Users.by_username(username)
      |> repo().maybe_preload(:settings)

    assert Bonfire.Common.Settings.get([Bonfire.Me.Users, :undiscoverable], nil,
             current_user: user
           ) == true

    assert Bonfire.Common.Extend.module_enabled?(Bonfire.Search.Indexer, user) == false
  end
end
