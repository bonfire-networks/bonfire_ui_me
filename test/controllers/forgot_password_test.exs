defmodule Bonfire.UI.Me.ForgotPasswordController.Test do
  # Tests the controller's neutral-response guarantee: it never reveals whether
  # an email exists or whether a magic link was sent.
  use Bonfire.UI.Me.ConnCase, async: true
  use Repatch.ExUnit
  import Swoosh.TestAssertions
  alias Bonfire.Me.Accounts

  doctest Bonfire.UI.Me.ForgotPasswordLive

  defp submit_forgot(email) do
    post(conn(), "/login/forgot-password", %{"forgot_password_fields" => %{"email" => email}})
  end

  # When mail can't be sent, `resend_confirm_email/2` falls out of its `with` and
  # returns the raw mailer error, which the controller can only render as the
  # generic "Something went wrong" box — so a broken mailer takes out the one
  # recovery path available to someone whose email address is already claimed.
  test "a mailer failure breaks the reset-link request instead of the neutral response" do
    account = fake_account!()
    fake_user!(account)

    Repatch.patch(Bonfire.Mailer, :send_now, fn _mail, _to ->
      {:error, {:partial_failure, [:no_credentials]}}
    end)

    resp = submit_forgot(account.email.email_address)

    refute resp.resp_body =~ "Check your inbox"
    assert resp.resp_body =~ "Something went wrong"
  end

  test "unknown email shows a neutral success message" do
    email = "unknown-#{System.unique_integer([:positive])}@example.com"
    resp = submit_forgot(email)
    assert resp.resp_body =~ "Check your inbox"
  end

  test "known email shows the same neutral success message" do
    account = fake_account!()
    resp = submit_forgot(account.email.email_address)
    assert resp.resp_body =~ "Check your inbox"
  end

  test "a blocked account still gets the neutral response without crashing" do
    account = fake_account!()
    user = fake_user!(account)
    {:ok, _} = Bonfire.Boundaries.Blocks.block(user, :ghost, :instance_wide)

    resp = submit_forgot(account.email.email_address)
    assert resp.resp_body =~ "Check your inbox"
  end

  test "blank email does not show the success state" do
    resp = submit_forgot("")
    refute resp.resp_body =~ "forgot-password-sent"
  end

  describe "passwordless magic-link carries `go`" do
    setup do
      Process.put([:bonfire_ui_me, :login, :passwordless_only], true)
      :ok
    end

    @go "/some-article"

    # Request a magic link for `email`, passing a top-level `go` (as the passwordless
    # login form does), then return the freshly-generated confirm token from the DB.
    defp request_magic_link(email, go) do
      post(conn(), "/login/forgot-password", %{
        "forgot_password_fields" => %{"email" => email},
        "go" => go
      })

      Accounts.get_by_email(email)
      |> repo().preload(:email)
      |> Map.fetch!(:email)
      |> Map.fetch!(:confirm_token)
    end

    test "requesting a link emails a URL containing the go destination" do
      account = fake_account!()
      fake_user!(account)

      request_magic_link(account.email.email_address, @go)

      assert_email_sent(fn email ->
        email.text_body =~ "go=" <> URI.encode_www_form(@go)
      end)
    end

    test "clicking the link (single user) redirects to go" do
      account = fake_account!()
      fake_user!(account)
      token = request_magic_link(account.email.email_address, @go)
      assert is_binary(token)

      conn = post(conn(), "/login/email/#{token}?go=#{URI.encode_www_form(@go)}")
      assert redirected_to(conn, 303) == @go
    end

    test "clicking the link (multiple users) goes to switch-user first, then to go once a profile is picked" do
      account = fake_account!()
      user1 = fake_user!(account)
      fake_user!(account)
      token = request_magic_link(account.email.email_address, @go)
      assert is_binary(token)

      conn = post(conn(), "/login/email/#{token}?go=#{URI.encode_www_form(@go)}")

      # First stop: the switch-user page (not straight to go). go rides in the session.
      switch_url = redirected_to(conn, 303)
      assert switch_url =~ "/switch-user"
      refute switch_url == @go

      # Render that page and grab the ACTUAL profile link a user would click.
      href =
        get(recycle(conn), switch_url)
        |> floki_response()
        |> Floki.find("a[href^='/switch-user/#{user1.character.username}']")
        |> Floki.attribute("href")
        |> List.first()

      assert is_binary(href), "expected a profile link for #{user1.character.username}"

      # Following that exact link switches to the profile and lands on go — carried
      # via the session (stashed from the email link), not via the link itself.
      assert redirected_to(get(recycle(conn), href)) == @go
    end

    test "a link requested by username goes to that account's email, and the screen shows only the username" do
      account = fake_account!()
      user = fake_user!(account)
      address = account.email.email_address

      resp = submit_forgot(user.character.username)

      assert_email_sent(to: address)
      assert resp.resp_body =~ "Check your inbox"
      assert resp.resp_body =~ user.character.username
      # showing the address found for a username would reveal it to whoever typed the username
      refute resp.resp_body =~ address
    end

    test "an unknown username gets the same screen, and no email is sent" do
      resp = submit_forgot("nobody#{System.unique_integer([:positive])}")

      assert resp.resp_body =~ "Check your inbox"
      assert_no_email_sent()
    end
  end

  # Setting the allowed domains enables passwordless (via the coupling in `passwordless_only?`), so
  # this drives the real create -> provider -> magic-link path, not a hand-built call.
  describe "signup by allowed email domain (magic link)" do
    setup do
      Process.put([:bonfire_me, Bonfire.Me.Accounts, :allowed_email_domains], ["example.com"])
      :ok
    end

    test "an unknown allowed-domain email is provisioned and gets a magic link" do
      email = "newbie-#{System.unique_integer([:positive])}@example.com"
      refute Accounts.get_by_email(email)

      resp = submit_forgot(email)
      assert resp.resp_body =~ "Check your inbox"

      assert Accounts.get_by_email(email)
      assert_email_sent()
    end

    test "an unknown off-list email provisions nothing and stays neutral" do
      email = "newbie-#{System.unique_integer([:positive])}@other.test"

      resp = submit_forgot(email)
      assert resp.resp_body =~ "Check your inbox"
      refute Accounts.get_by_email(email)
    end

    test "clicking the provisioned link logs in" do
      email = "newbie-#{System.unique_integer([:positive])}@example.com"
      submit_forgot(email)

      token =
        Accounts.get_by_email(email)
        |> repo().preload(:email)
        |> Map.fetch!(:email)
        |> Map.fetch!(:confirm_token)

      assert is_binary(token)
      conn = post(conn(), "/login/email/#{token}")
      assert conn.status in [302, 303]
    end
  end

  # A sign-in link and a reset link are different pages, so what a link does never depends on the instance setting at the time it is opened. Opening either only shows a page: its button uses the token up, so a mail scanner opening the link can't.
  describe "sign-in links and reset links" do
    @go "/some-article"

    defp token_for(address) do
      Accounts.get_by_email(address)
      |> repo().preload(:email)
      |> Map.fetch!(:email)
      |> Map.fetch!(:confirm_token)
    end

    defp expire_token(address) do
      email = Accounts.get_by_email(address) |> repo().preload(:email) |> Map.fetch!(:email)

      {:ok, _} =
        email
        |> Ecto.Changeset.change(confirm_until: DateTime.add(DateTime.utc_now(), -60))
        |> repo().update()
    end

    defp passwordless(on?), do: Process.put([:bonfire_ui_me, :login, :passwordless_only], on?)

    defp account_with_token(kind) do
      account = fake_account!()
      fake_user!(account)
      address = account.email.email_address

      # a request made on a passwordless instance mails a sign-in link, otherwise a reset link
      passwordless(kind == :sign_in)
      submit_forgot(address)
      {address, token_for(address)}
    end

    test "opening a sign-in link only shows a page: nobody is signed in and the token stays" do
      {address, token} = account_with_token(:sign_in)

      conn = get(conn(), "/login/email/#{token}?go=#{URI.encode_www_form(@go)}")

      assert conn.status == 200
      refute get_session(conn, :current_account_id)
      assert [form] = Floki.find(floki_response(conn), "#confirm-link-form")
      assert [action] = Floki.attribute(form, "action")
      assert action == "/login/email/#{token}?go=#{URI.encode_www_form(@go)}"
      assert token_for(address) == token
    end

    test "a mail scanner opening the sign-in link twice doesn't stop the person signing in" do
      {_address, token} = account_with_token(:sign_in)

      assert get(conn(), "/login/email/#{token}").status == 200
      assert get(build_conn(), "/login/email/#{token}").status == 200

      conn = post(build_conn(), "/login/email/#{token}?go=#{URI.encode_www_form(@go)}")
      assert redirected_to(conn, 303) == @go
    end

    test "a sign-in link keeps signing in after the instance stops being passwordless" do
      {_address, token} = account_with_token(:sign_in)
      passwordless(false)

      conn = post(conn(), "/login/email/#{token}?go=#{URI.encode_www_form(@go)}")
      assert redirected_to(conn, 303) == @go
    end

    test "opening a reset link only shows a page, and its button starts the password change" do
      {address, token} = account_with_token(:reset)

      conn = get(conn(), "/login/forgot-password/#{token}")
      assert conn.status == 200
      refute get_session(conn, :resetting_password)
      assert [_] = Floki.find(floki_response(conn), "#confirm-link-form")
      assert token_for(address) == token

      conn = post(build_conn(), "/login/forgot-password/#{token}")
      assert get_session(conn, :resetting_password)
      assert redirected_to(conn) =~ "password"
    end

    for {label, kind, prefix} <- [
          {"sign-in", :sign_in, "/login/email/"},
          {"reset", :reset, "/login/forgot-password/"}
        ] do
      test "an expired #{label} link is refused and signs nobody in" do
        {address, token} = account_with_token(unquote(kind))
        expire_token(address)

        conn = post(conn(), unquote(prefix) <> token)

        assert conn.status == 200
        assert conn.resp_body =~ "invalid or has expired"
        refute get_session(conn, :current_account_id)
      end

      test "an unknown #{label} link says it is invalid" do
        conn = get(conn(), unquote(prefix) <> "NOTATOKEN#{System.unique_integer([:positive])}")

        assert conn.resp_body =~ "invalid or has expired"
      end
    end

    test "a sign-in link sent before the split still works on the old path" do
      {_address, token} = account_with_token(:sign_in)

      conn = get(conn(), "/login/forgot-password/#{token}")
      # the page hands over to the sign-in route
      assert [form] = Floki.find(floki_response(conn), "#confirm-link-form")
      assert [action] = Floki.attribute(form, "action")
      assert action == "/login/email/#{token}"

      conn = post(build_conn(), "/login/forgot-password/#{token}?go=#{URI.encode_www_form(@go)}")
      assert redirected_to(conn, 303) == @go
    end
  end

  describe "domain-restriction hint on the sign-in entry" do
    @hint "limited to certain email domains"

    test "shows when signups are domain-restricted and the visitor has no invite" do
      Process.put([:bonfire_me, Accounts, :allowed_email_domains], ["example.com"])
      resp = get(conn(), "/login/forgot-password")
      assert resp.resp_body =~ @hint
    end

    test "is hidden when there is no domain restriction" do
      resp = get(conn(), "/login/forgot-password")
      refute resp.resp_body =~ @hint
    end

    test "is hidden for a visitor arriving with an invite (an invite bypasses the restriction)" do
      Process.put([:bonfire_me, Accounts, :allowed_email_domains], ["example.com"])

      resp =
        conn()
        |> Plug.Test.init_test_session(%{"invite" => "some-token"})
        |> get("/login/forgot-password")

      refute resp.resp_body =~ @hint
    end
  end
end
