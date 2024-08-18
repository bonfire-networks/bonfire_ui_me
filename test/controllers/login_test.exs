defmodule Bonfire.UI.Me.LoginController.Test do
  use Bonfire.UI.Me.ConnCase, async: true
  alias Bonfire.Me.Accounts

  test "form renders" do
    conn = conn()
    conn = get(conn, "/login")
    doc = floki_response(conn)
    assert [form] = Floki.find(doc, "#login-form")
    refute [] == Floki.find(form, "input[type='text']")
    assert [_] = Floki.find(form, "input[type='password']")
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  describe "required fields" do
    test "missing both" do
      conn = conn()
      conn = post(conn, "/login", %{"login_fields" => %{}})

      # assert_raise RuntimeError, debug(floki_response(conn))
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#login-form")
      refute [] == Floki.find(form, "input[type='text']")

      # FIXME?

      # assert [email_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='login-form_email']")
      # assert "can't be blank" == Floki.text(email_error)
      assert [_] = Floki.find(form, "input[type='password']")

      # assert [password_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='login-form_password']")
      # assert "can't be blank" == Floki.text(password_error)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing password" do
      conn = conn()
      email = email()

      conn =
        post(conn, "/login", %{
          "login_fields" => %{"email_or_username" => email}
        })

      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#login-form")
      assert [_] = Floki.find(form, "input[type='password']")

      # assert [password_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='login-form_password']")
      # assert "can't be blank" == Floki.text(password_error)
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing email" do
      conn = conn()
      password = password()

      conn = post(conn, "/login", %{"login_fields" => %{"password" => password}})

      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#login-form")
      refute [] == Floki.find(form, "input[type='text']")

      # assert [email_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='login-form_email']")
      # assert "can't be blank" == Floki.text(email_error)
      assert [_] = Floki.find(form, "button[type='submit']")
    end
  end

  test "not found" do
    conn = conn()
    email = email()
    password = password()

    params = %{
      "login_fields" => %{"email_or_username" => email, "password" => password}
    }

    conn = post(conn, "/login", params)
    # assert_raise RuntimeError, debug(floki_response(conn))
    doc = floki_response(conn)
    assert [login] = Floki.find(doc, "#login")
    # assert [div] = Floki.find(doc, "div.box__warning")
    # assert [span] = Floki.find(div, "span")
    assert Floki.text(login) =~ ~r/incorrect/
    assert [_] = Floki.find(login, "form")
  end

  test "not activated" do
    conn = conn()
    account = fake_account!(%{}, must_confirm?: true)

    params = %{
      "login_fields" => %{
        "email_or_username" => account.email.email_address,
        "password" => account.credential.password
      }
    }

    conn = post(conn, "/login", params)
    # debug(conn: conn)

    # assert_raise RuntimeError, debug(floki_response(conn))
    doc = floki_response(conn)
    assert [login] = Floki.find(doc, "#login-form")
    # assert [div] = Floki.find(doc, "div.box__warning")
    # assert [span] = Floki.find(div, "span")
    assert Floki.text(login) =~ ~r/click the link/
    assert [_] = Floki.find(login, "form")
  end

  describe "success" do
    test "with email for an account with 1 user identity" do
      conn = conn()
      account = fake_account!()
      _user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)

      params = %{
        "login_fields" => %{
          "email_or_username" => account.email.email_address,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)
      assert redirected_to(conn, 303) == "/"
    end

    test "with email for an account with multiple user identities" do
      conn = conn()
      account = fake_account!()
      _user1 = fake_user!(account)
      _user2 = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)

      params = %{
        "login_fields" => %{
          "email_or_username" => account.email.email_address,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)
      assert redirected_to(conn, 303) == "/switch-user"
    end

    test "with username" do
      conn = conn()
      account = fake_account!()
      user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)

      params = %{
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      }

      conn = post(conn, "/login", params)
      assert redirected_to(conn, 303) == "/"
    end
  end
end
