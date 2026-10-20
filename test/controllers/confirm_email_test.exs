defmodule Bonfire.UI.Me.ConfirmEmailController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  import Swoosh.TestAssertions
  alias Bonfire.Me.Fake

  setup_all do
    Bonfire.Me.Fake.clear_caches()
    :ok
  end

  describe "request" do
    test "must be a guest" do
    end

    test "form renders" do
      conn = conn()
      conn = get(conn, "/signup/email/confirm")
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")
      assert [] = Floki.find(doc, ".error")
    end

    test "absence validation" do
      conn = conn()
      conn = post(conn, "/signup/email/confirm", %{})
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")
      assert [] = Floki.find(doc, ".error")

      assert [err] =
               Floki.find(
                 form,
                 "[phx-feedback-for='confirm_email_fields[email]']"
               )

      assert "can't be blank" == Floki.text(err)
    end

    test "format validation" do
      conn = conn()

      conn =
        post(conn, "/signup/email/confirm", %{
          "confirm_email_fields" => %{"email" => Faker.Pokemon.name()}
        })

      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")
      assert [] = Floki.find(doc, ".error")

      assert [err] =
               Floki.find(
                 form,
                 "[phx-feedback-for='confirm_email_fields[email]']"
               )

      assert "has invalid format" == Floki.text(err)
    end

    test "not found" do
      conn = conn()

      conn =
        post(conn, "/signup/email/confirm", %{
          "confirm_email_fields" => %{"email" => email()}
        })

      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    # TODO
    # test "expired" do
    #   conn = conn()
    # end

    test "success" do
      conn = conn()
      account = fake_account!(%{}, must_confirm?: true)
      conn = get(conn, "/signup/email/confirm")
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")

      conn =
        post(recycle(conn), "/signup/email/confirm", %{
          "confirm_email_fields" => %{"email" => account.email.email_address}
        })

      doc = floki_response(conn)
      # assert [] = Floki.find(doc, "#confirm-email-form")
      assert [conf] = Floki.find(doc, ".alert-success")
      assert Floki.text(conf) =~ ~r/emailed you/
    end
  end

  describe "resending a confirmation link" do
    defp resend(conn, email) do
      post(conn, "/signup/email/confirm", %{"confirm_email_fields" => %{"email" => email}})
    end

    defp flush_emails do
      receive do
        {:email, _} -> flush_emails()
      after
        0 -> :ok
      end
    end

    test "a known unconfirmed, an unknown and an already confirmed email all get the same answer" do
      unconfirmed = fake_account!(%{}, must_confirm?: true)

      {:ok, confirmed} =
        Bonfire.Me.Accounts.confirm_email(fake_account!(%{}, must_confirm?: true))

      unknown = email()

      # accounts may send their own mail when created, so start from an empty mailbox
      flush_emails()

      answers =
        for address <- [unconfirmed.email.email_address, unknown, confirmed.email.email_address] do
          conn = resend(conn(), address)

          # no redirect and no error, so the answer doesn't depend on whether an account exists
          assert conn.status == 200
          doc = floki_response(conn)
          assert [] = Floki.find(doc, ".alert-error")
          assert [ok] = Floki.find(doc, ".alert-success")
          Floki.text(ok)
        end

      assert [answer] = Enum.uniq(answers)
      assert answer =~ ~r/emailed you/

      # and only the account waiting for confirmation got a mail
      assert_email_sent(to: unconfirmed.email.email_address)
      assert_no_email_sent()
    end

    test "a resend for an already confirmed address sends nothing and leaves it confirmed" do
      {:ok, confirmed} =
        Bonfire.Me.Accounts.confirm_email(fake_account!(%{}, must_confirm?: true))

      address = confirmed.email.email_address
      flush_emails()

      # positive control first: the page answered
      assert [_] = Floki.find(resend(conn(), address) |> floki_response(), ".alert-success")

      assert_no_email_sent()

      email =
        Bonfire.Me.Accounts.get_by_email(address) |> repo().preload(:email) |> Map.fetch!(:email)

      assert %DateTime{} = email.confirmed_at
    end

    test "after a failed link, a resend shows the success message and not the old error" do
      account = fake_account!(%{}, must_confirm?: true)

      conn = get(conn(), "/signup/email/confirm/#{confirm_token()}")
      assert [_] = Floki.find(floki_response(conn), ".alert-error")

      doc = conn |> recycle() |> resend(account.email.email_address) |> floki_response()

      assert [] = Floki.find(doc, ".alert-error")
      assert [_] = Floki.find(doc, ".alert-success")
    end

    test "visiting the page after a resend doesn't claim another link was just sent" do
      account = fake_account!(%{}, must_confirm?: true)

      conn = resend(conn(), account.email.email_address)
      assert [_] = Floki.find(floki_response(conn), ".alert-success")

      doc = conn |> recycle() |> get("/signup/email/confirm") |> floki_response()

      assert [] = Floki.find(doc, ".alert-success")
      assert [] = Floki.find(doc, ".alert-error")
    end

    test "a session that still holds the old error and requested flags renders a clean page" do
      doc =
        conn()
        |> Plug.Test.init_test_session(%{error: :not_found, requested: true})
        |> get("/signup/email/confirm")
        |> floki_response()

      assert [] = Floki.find(doc, ".alert-error")
      assert [] = Floki.find(doc, ".alert-success")
    end
  end

  describe "confirmation" do
    test "must be a guest" do
      # TODO
    end

    test "not found" do
      conn = conn()
      conn = get(conn, "/signup/email/confirm/#{confirm_token()}")
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")
      assert [err] = Floki.find(doc, ".alert-error")
      assert Floki.text(err) =~ ~r/invalid confirmation link/i
    end

    defp unconfirmed_account do
      # Explicitly require confirmation to bypass is_first_account? sandbox isolation
      {:ok, account} = Bonfire.Me.Accounts.signup(signup_form(), must_confirm?: true)
      account
    end

    defp stored_email(account) do
      Bonfire.Me.Accounts.get_by_email(account.email.email_address)
      |> repo().preload(:email)
      |> Map.fetch!(:email)
    end

    test "opening the link shows a Confirm page and leaves the token unused" do
      account = unconfirmed_account()
      token = account.email.confirm_token

      conn = get(conn(), "/signup/email/confirm/#{token}")

      assert conn.status == 200
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-link-form")
      assert Floki.attribute(form, "action") == ["/signup/email/confirm/#{token}"]
      assert [button] = Floki.find(form, "button[type='submit']")
      assert Floki.text(button) =~ "Confirm"

      email = stored_email(account)
      assert email.confirm_token == token
      assert is_nil(email.confirmed_at)
    end

    test "the Confirm page keeps go and redirect_uri in its form action" do
      token = unconfirmed_account().email.confirm_token

      doc =
        get(
          conn(),
          "/signup/email/confirm/#{token}?go=#{URI.encode_www_form("/some-article")}&redirect_uri=#{URI.encode_www_form("totnespulse://oauth")}"
        )
        |> floki_response()

      assert [form] = Floki.find(doc, "#confirm-link-form")
      assert [action] = Floki.attribute(form, "action")
      assert %URI{path: path, query: query} = URI.parse(action)
      assert path == "/signup/email/confirm/#{token}"

      assert URI.decode_query(query) == %{
               "go" => "/some-article",
               "redirect_uri" => "totnespulse://oauth"
             }
    end

    test "a mail scanner opening the link twice doesn't stop the person confirming" do
      account = unconfirmed_account()
      path = "/signup/email/confirm/#{account.email.confirm_token}"

      assert get(conn(), path).status == 200
      assert get(build_conn(), path).status == 200

      assert redirected_to(post(build_conn(), path)) == "/switch-user"
      assert %DateTime{} = stored_email(account).confirmed_at
    end

    test "the Confirm page submits itself on the first real human input" do
      doc =
        get(conn(), "/signup/email/confirm/#{unconfirmed_account().email.confirm_token}")
        |> floki_response()

      assert [root] = Floki.find(doc, "[data-role=confirm_link]")
      assert Floki.attribute(root, "x-on:pointerdown.window") != []
      assert Floki.attribute(root, "x-on:mousemove.window") != []
    end

    test "an expired link says so on the page itself" do
      account = unconfirmed_account()

      {:ok, _} =
        stored_email(account)
        |> Ecto.Changeset.change(confirm_until: DateTime.add(DateTime.utc_now(), -60))
        |> repo().update()

      doc =
        get(conn(), "/signup/email/confirm/#{account.email.confirm_token}") |> floki_response()

      assert [err] = Floki.find(doc, ".alert-error")
      assert Floki.text(err) =~ ~r/expired/i
    end

    test "redeeming an unknown token shows the invalid message" do
      doc = post(conn(), "/signup/email/confirm/#{confirm_token()}") |> floki_response()

      assert [err] = Floki.find(doc, ".alert-error")
      assert Floki.text(err) =~ ~r/invalid confirmation link/i
    end

    test "success" do
      conn = conn()
      account = unconfirmed_account()
      conn = post(conn, "/signup/email/confirm/#{account.email.confirm_token}")
      assert redirected_to(conn) == "/switch-user"
    end

    test "stashes go so the post-confirm flow (create profile) can reach it" do
      conn = conn()
      {:ok, account} = Bonfire.Me.Accounts.signup(signup_form(), must_confirm?: true)

      conn =
        post(
          conn,
          "/signup/email/confirm/#{account.email.confirm_token}?go=#{URI.encode_www_form("/some-article")}"
        )

      # New account (no profile yet) → switch-user/create-profile, with go stashed in
      # its cookie so redirect_to_previous_go can send them there once set up.
      assert redirected_to(conn) =~ "/switch-user"
      assert go_target(conn) == "/some-article"
    end

    test "success with custom scheme redirect_uri for mobile deep-linking" do
      conn = conn()
      {:ok, account} = Bonfire.Me.Accounts.signup(signup_form(), must_confirm?: true)

      conn =
        post(
          conn,
          "/signup/email/confirm/#{account.email.confirm_token}?redirect_uri=#{URI.encode_www_form("totnespulse://oauth")}"
        )

      assert redirected_to(conn) == "totnespulse://oauth"
    end

    test "redirect_uri with blocked scheme falls back to default" do
      conn = conn()
      {:ok, account} = Bonfire.Me.Accounts.signup(signup_form(), must_confirm?: true)

      conn =
        post(
          conn,
          "/signup/email/confirm/#{account.email.confirm_token}?redirect_uri=#{URI.encode_www_form("https://evil.com")}"
        )

      assert redirected_to(conn) == "/switch-user"
    end

    test "pressing Confirm twice within the grace period works both times" do
      account = unconfirmed_account()
      path = "/signup/email/confirm/#{account.email.confirm_token}"

      assert redirected_to(post(conn(), path)) == "/switch-user"
      assert redirected_to(post(build_conn(), path)) == "/switch-user"
    end

    test "pressing Confirm after the grace period sends the person to log in" do
      account = unconfirmed_account()
      path = "/signup/email/confirm/#{account.email.confirm_token}"
      assert redirected_to(post(conn(), path)) == "/switch-user"

      {:ok, _} =
        stored_email(account)
        |> Ecto.Changeset.change(confirm_until: DateTime.add(DateTime.utc_now(), -60))
        |> repo().update()

      # the link page itself also sends them on, instead of offering a button that can't work
      assert redirected_to(get(build_conn(), path)) == "/login"
      assert redirected_to(post(build_conn(), path)) == "/login"
    end
  end
end
