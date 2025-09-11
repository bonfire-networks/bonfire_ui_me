defmodule Bonfire.UI.Me.SignupController.Test do
  use Bonfire.UI.Me.ConnCase, async: true
  use Repatch.ExUnit

  test "form renders" do
    conn = conn()
    conn = get(conn, "/signup")
    doc = floki_response(conn)
    assert [form] = Floki.find(doc, "#signup-form")
    assert [_] = Floki.find(form, "input[type='email']")
    assert [_, _] = Floki.find(form, "input[type='password']")
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  describe "required fields" do
    test "missing both" do
      conn = conn()
      conn = post(conn, "/signup", %{"account" => %{}})
      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [form] = Floki.find(signup, "#signup-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_, _] = Floki.find(form, "input[type='password']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing password" do
      conn = conn()
      email = email()

      conn =
        post(conn, "/signup", %{
          "account" => %{"email" => %{"email_address" => email}}
        })

      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [form] = Floki.find(signup, "#signup-form")
      assert [_, _] = Floki.find(form, "input[type='password']")

      # assert [password_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='signup-form_password']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing email" do
      conn = conn()
      password = password()

      conn =
        post(conn, "/signup", %{
          "account" => %{"credential" => %{"password" => password}}
        })

      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [form] = Floki.find(signup, "#signup-form")
      assert [_] = Floki.find(form, "input[type='email']")

      # assert [email_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='signup-form_email']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end
  end

  setup do
    Bonfire.Me.Fake.clear_caches()
    :ok
  end

  test "can signup" do
    #  create a first user since confirmation otherwise not required
    fake_user!()
    # Clear caches to ensure test email doesn't collide with existing accounts
    # Bonfire.Me.Fake.clear_caches()
    conn = conn()
    email = email()
    password = password()

    conn =
      post(conn, "/signup", %{
        "account" => %{
          "email" => %{"email_address" => email},
          "credential" => %{"password" => password}
        }
      })

    doc = floki_response(conn)
    assert [signup] = Floki.find(doc, "#signup")
    assert [p] = Floki.find(doc, "#signup_success")
    assert Floki.text(p) =~ ~r/confirm your email/s
    assert [] = Floki.find(doc, "#signup-form")
  end

  describe "invite handling" do
    setup do
      # Create an admin user who can create invites
      some_account = fake_account!()

      {:ok, admin_user} =
        fake_user!(some_account)
        |> Bonfire.Me.Users.make_admin()

      Bonfire.Me.Fake.clear_caches()

      # Create a valid invite
      {:ok, invite} =
        Bonfire.Invite.Links.create(admin_user, %{
          "max_uses" => 3,
          "max_days_valid" => 7
        })

      # Patch function to simulate invite-only instance
      Repatch.patch(Bonfire.Me.Accounts, :instance_is_invite_only?, fn -> true end)

      %{invite: invite, admin_user: admin_user}
    end

    test "stores real invite code from params in session", %{invite: invite} do
      conn = conn()
      invite_id = invite.id

      conn = get(conn, "/signup?invite=#{invite_id}")

      # Check that invite is stored in session
      assert get_session(conn, :invite) == invite_id

      # Form should still render
      doc = floki_response(conn)
      assert [_form] = Floki.find(doc, "#signup-form")
    end

    test "uses real invite from session during signup on invite-only instance", %{invite: invite} do
      conn = conn()
      invite_id = invite.id
      email = email()
      password = password()

      # First, visit signup with invite to store it in session
      conn = get(conn, "/signup?invite=#{invite_id}")
      assert get_session(conn, :invite) == invite_id

      # Then attempt signup
      conn =
        post(conn, "/signup", %{
          "account" => %{
            "email" => %{"email_address" => email},
            "credential" => %{"password" => password}
          }
        })

      # Should succeed because valid invite was in session
      doc = floki_response(conn)
      assert [_success] = Floki.find(doc, "#signup_success")
      assert [] = Floki.find(doc, "#signup-form")

      # Verify the function was called
      assert Repatch.called?(Bonfire.Me.Accounts, :instance_is_invite_only?, 0)

      # Verify invite was actually redeemed (uses decreased by 1)
      {:ok, updated_invite} = Bonfire.Invite.Links.get(invite_id)
      # was 3, now 2
      assert updated_invite.max_uses == 2
    end

    test "signup fails on invite-only instance without invite" do
      conn = conn()
      email = email()
      password = password()

      conn =
        post(conn, "/signup", %{
          "account" => %{
            "email" => %{"email_address" => email},
            "credential" => %{"password" => password}
          }
        })

      # Should fail without invite
      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [_form] = Floki.find(doc, "#signup-form")

      # Verify the function was called
      assert Repatch.called?(Bonfire.Me.Accounts, :instance_is_invite_only?, 0)
    end

    test "can simulate SSO signup with invite", %{invite: invite} do
      invite_id = invite.id
      email = email()

      # First, visit signup with invite to store it in session (like SSO would do)
      conn = conn()
      conn = get(conn, "/signup?invite=#{invite_id}")
      assert get_session(conn, :invite) == invite_id

      # Then simulate what SSO controller would do
      assert {:ok, _account} =
               Bonfire.UI.Me.SignupController.attempt_signup(
                 conn,
                 %{openid_email: email},
                 %{},
                 must_confirm?: false
               )

      # Verify invite was redeemed
      {:ok, updated_invite} = Bonfire.Invite.Links.get(invite_id)
      # was 3, now 2
      assert updated_invite.max_uses == 2
    end
  end
end
