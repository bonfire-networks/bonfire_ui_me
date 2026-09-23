defmodule Bonfire.UI.Me.LoginController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  import Swoosh.TestAssertions
  alias Bonfire.Me.Accounts

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
    assert [] = Floki.find(doc, "#dock-login-action")
  end

  describe "SSO-first (a trusted sign-in service, no allowed domains)" do
    setup do
      Process.put([:bonfire_open_id, :oauth2_providers],
        github: [display_name: "GitHub", redirect_uri: "/openid/client/github"]
      )

      Process.put([:bonfire_me, Accounts, :trusted_signup_providers], [:github])
      :ok
    end

    test "shows the sign-in service and folds the email login behind \"Use email instead\"" do
      doc = get(conn(), "/login") |> floki_response()

      assert Floki.text(doc) =~ "Sign in with GitHub"
      assert [folded] = Floki.find(doc, "details[data-role=email_login]")
      assert Floki.text(folded) =~ "Use email instead"
      # still there, just folded: the escape hatch if the sign-in service is down
      assert [_] = Floki.find(folded, "#login-form")
    end

    test "with allowed email domains too, the email login stays up front" do
      Process.put([:bonfire_me, Accounts, :allowed_email_domains], ["example.com"])

      doc = get(conn(), "/login") |> floki_response()

      assert [] = Floki.find(doc, "details[data-role=email_login]")
      assert [_] = Floki.find(doc, "#login-form")
    end
  end

  describe "passwordless_only? mode" do
    setup do
      Process.put([:bonfire_ui_me, :login, :passwordless_only], true)
      :ok
    end

    test "renders the magic-link form with the password field folded away, and no signup" do
      conn = get(conn(), "/login")
      doc = floki_response(conn)

      assert [form] = Floki.find(doc, "#login-form")
      assert [_] = Floki.find(form, "input[name='login_fields[email_or_username]']")
      assert Floki.text(form) =~ ~r/Send sign-in link/
      # the only password field is inside the collapsed "I have a password" disclosure
      assert [_] = Floki.find(form, "input[type='password']")
      assert [_] = Floki.find(form, "details[data-role=password_login] input[type='password']")
      # Signup prompt should NOT be visible in passwordless-only mode.
      refute Floki.text(doc) =~ ~r/Don't have an account/
    end

    test "\"I have a password\" reveals a password field in the same form, with its own button" do
      doc = get(conn(), "/login") |> floki_response()

      assert [form] = Floki.find(doc, "#login-form")
      assert [disclosure] = Floki.find(form, "details[data-role=password_login]")
      assert Floki.text(disclosure) =~ "I have a password"
      assert [_] = Floki.find(disclosure, "input[type='password']")
      assert [_] = Floki.find(disclosure, "button[name=login_with][value=password]")
    end

    defp login_with_password(email_or_username, password) do
      post(conn(), "/login/email", %{
        "login_fields" => %{"email_or_username" => email_or_username, "password" => password},
        "login_with" => "password"
      })
    end

    test "an account with a password can still log in with it" do
      account = fake_account!()
      _user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)

      conn = login_with_password(account.email.email_address, account.credential.password)

      assert redirected_to(conn, 303) == "/"
    end

    test "a wrong password shows the error with the password field open and the email kept" do
      account = fake_account!()
      {:ok, account} = Accounts.confirm_email(account)

      doc =
        login_with_password(account.email.email_address, "not-the-password")
        |> floki_response()

      assert [form] = Floki.find(doc, "#login-form")
      assert Floki.text(form) =~ "Account not found"
      assert [_] = Floki.find(form, "details[data-role=password_login][open]")

      assert Floki.attribute(form, "input[name='login_fields[email_or_username]']", "value") == [
               account.email.email_address
             ]
    end

    test "the sign-in field takes an email or a username (the browser doesn't demand an email)" do
      doc = get(conn(), "/login") |> floki_response()

      assert [form] = Floki.find(doc, "#login-form")
      assert [input] = Floki.find(form, "input[name='login_fields[email_or_username]']")
      assert Floki.attribute(input, "type") == ["text"]
      assert Floki.text(form) =~ "Email or username"
    end

    test "pressing Enter in the password field logs in with the password instead of sending a link" do
      account = fake_account!()
      _user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)

      # Enter submits with the form's first button ("Send sign-in link"), so no `login_with` is sent
      conn =
        post(conn(), "/login/email", %{
          "login_fields" => %{
            "email_or_username" => account.email.email_address,
            "password" => account.credential.password
          }
        })

      assert redirected_to(conn, 303) == "/"
    end

    test "an account with a password can log in with its username" do
      account = fake_account!()
      user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)

      conn = login_with_password(user.character.username, account.credential.password)

      assert redirected_to(conn, 303) == "/"
    end

    test "looks like a login form to password managers: no \"forgot\" action, the login page's field names" do
      doc = get(conn(), "/login") |> floki_response()

      [form] = Floki.find(doc, "#login-form")
      assert Floki.attribute(form, "action") == ["/login/email"]

      assert Floki.attribute(
               form,
               "input[name='login_fields[email_or_username]']",
               "autocomplete"
             ) ==
               ["username"]

      assert Floki.attribute(form, "input[name='login_fields[password]']", "autocomplete") ==
               ["current-password"]
    end

    test "\"Send sign-in link\" from the login form emails a link" do
      account = fake_account!()
      fake_user!(account)

      resp =
        post(conn(), "/login/email", %{
          "login_fields" => %{
            "email_or_username" => account.email.email_address,
            "password" => ""
          }
        })

      assert resp.resp_body =~ "Check your inbox"
      assert_email_sent(to: account.email.email_address)
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

  describe "already signed in, visiting the embed Sign in link (/remote_interaction?...&url=)" do
    setup do
      account = fake_account!()
      user = fake_user!(account)
      {:ok, account} = Accounts.confirm_email(account)
      System.put_env("IFRAME_ALLOWED_ORIGINS", @external_host)
      on_exit(fn -> System.delete_env("IFRAME_ALLOWED_ORIGINS") end)
      {:ok, account: account, user: user}
    end

    test "honors the `url` return-to (local path) instead of dumping to the dashboard", %{
      account: account,
      user: user
    } do
      conn = conn(user: user, account: account)

      conn =
        get(conn, "/remote_interaction?" <> URI.encode_query(type: "reply", url: "/thread/abc"))

      assert redirected_to(conn) == "/thread/abc"
    end

    test "returns to an allowed embed origin with a bonfire_embed_token (so they can comment)", %{
      account: account,
      user: user
    } do
      conn = conn(user: user, account: account)

      conn =
        get(conn, "/remote_interaction?" <> URI.encode_query(type: "reply", url: @external_url))

      redirect = redirected_to(conn)
      assert redirect =~ @external_url
      assert redirect =~ "bonfire_embed_token="
    end

    test "drops a malicious external `url` (not an allowed origin) instead of open-redirecting",
         %{
           account: account,
           user: user
         } do
      conn = conn(user: user, account: account)

      conn =
        get(
          conn,
          "/remote_interaction?" <>
            URI.encode_query(type: "reply", url: "https://evil.example/steal")
        )

      redirect = redirected_to(conn)
      refute redirect =~ "evil.example"
      assert redirect == "/"
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

    test "redirect drops external go and falls back to default when origin is not allowed", %{
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
      assert redirect == "/"
      refute redirect =~ @external_host
      refute redirect =~ "bonfire_embed_token="
    end

    test "redirect drops a malicious external go when no origins are allowed", %{
      account: account,
      user: user
    } do
      System.delete_env("IFRAME_ALLOWED_ORIGINS")

      conn =
        conn()
        |> Plug.Conn.fetch_session()
        |> Plug.Conn.put_session(:go, "https://evil.example/steal")

      conn = post(conn, "/login", login_params(user, account))

      redirect = redirected_to(conn, 303)
      assert redirect == "/"
      refute redirect =~ "evil.example"
    end
  end
end
