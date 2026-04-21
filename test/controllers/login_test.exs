defmodule Bonfire.UI.Me.LoginController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken

  @external_host "https://blog.example.com"
  @external_url "#{@external_host}/my-article/"

  test "form renders" do
    conn = conn()
    conn = get(conn, "/login")
    doc = floki_response(conn)
    assert [form] = Floki.find(doc, "#login-form")
    refute [] == Floki.find(form, "input[type='text']")
    assert [_] = Floki.find(form, "input[type='password']")
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  describe "passwordless_only? mode" do
    setup do
      Application.put_env(:bonfire_ui_me, :login, passwordless_only: true)
      on_exit(fn -> Application.delete_env(:bonfire_ui_me, :login) end)
      :ok
    end

    test "renders email-only magic-link form, hides password and signup" do
      conn = get(conn(), "/login")
      doc = floki_response(conn)

      assert [form] = Floki.find(doc, "#login-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [] = Floki.find(form, "input[type='password']")
      assert Floki.text(form) =~ ~r/Send login link/
      # Signup prompt should NOT be visible in passwordless-only mode.
      refute Floki.text(doc) =~ ~r/Don't have an account/
    end

    test "posts to forgot-password endpoint" do
      conn = get(conn(), "/login")
      doc = floki_response(conn)
      [form] = Floki.find(doc, "#login-form")
      assert Floki.attribute(form, "action") |> List.first() =~ "/login/forgot-password"
    end
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
    assert [_] = Floki.find(login, "#login-form")
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

  describe "embed token on redirect" do
    # see also Bonfire.UI.Social.CommentsEmbedTokenTest

    setup do
      account = fake_account!()
      user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)
      System.put_env("IFRAME_ALLOWED_ORIGINS", @external_host)
      on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)
      {:ok, account: account, user: user}
    end

    defp login_params(user, account, extra \\ %{}) do
      Map.merge(extra, %{
        "login_fields" => %{
          "email_or_username" => user.character.username,
          "password" => account.credential.password
        }
      })
    end

    test "redirect includes bonfire_embed_token when go is an allowed external origin", %{
      account: account,
      user: user
    } do
      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, @external_url)

      conn = post(conn, "/login", login_params(user, account))

      redirect = redirected_to(conn, 303)
      assert redirect =~ @external_url
      assert redirect =~ "bonfire_embed_token="
    end

    test "redirect includes bonfire_embed_token when IFRAME_ALLOWED_ORIGINS is a bare hostname",
         %{account: account, user: user} do
      System.put_env("IFRAME_ALLOWED_ORIGINS", "blog.example.com")

      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, @external_url)

      conn = post(conn, "/login", login_params(user, account))

      redirect = redirected_to(conn, 303)
      assert redirect =~ @external_url
      assert redirect =~ "bonfire_embed_token="
    end

    test "redirect includes token when go comes as form param", %{account: account, user: user} do
      conn = post(conn(), "/login", login_params(user, account, %{"go" => @external_url}))

      redirect = redirected_to(conn, 303)
      assert redirect =~ @external_url
      assert redirect =~ "bonfire_embed_token="
    end

    test "redirect does NOT include bonfire_embed_token when go is an internal path", %{
      account: account,
      user: user
    } do
      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, "/feed")

      conn = post(conn, "/login", login_params(user, account))
      refute redirected_to(conn, 303) =~ "bonfire_embed_token="
    end

    test "redirect goes to external go URL without token when origin is not allowed", %{
      account: account,
      user: user
    } do
      System.put_env("IFRAME_ALLOWED_ORIGINS", "https://other.example.com")

      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, @external_url)

      conn = post(conn, "/login", login_params(user, account))

      redirect = redirected_to(conn, 303)
      assert redirect =~ @external_url
      refute redirect =~ "bonfire_embed_token="
    end
  end
end
