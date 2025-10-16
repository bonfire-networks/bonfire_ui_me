defmodule Bonfire.UI.Me.ConfirmEmailController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
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

    test "success" do
      #  create a first user since confirmation otherwise not required
      fake_user!()
      # Clear the cache so the next signup sees that an account exists
      Bonfire.Me.Accounts.clear_cache()

      conn = conn()
      {:ok, account} = Bonfire.Me.Accounts.signup(signup_form())
      conn = get(conn, "/signup/email/confirm/#{account.email.confirm_token}")
      assert redirected_to(conn) == "/switch-user"
    end

    test "cannot confirm twice" do
      #  create a first user since confirmation otherwise not required
      fake_user!()
      # Clear the cache so the next signup sees that an account exists
      Bonfire.Me.Accounts.clear_cache()

      # needs template fix - no feedback
      conn = conn()
      {:ok, account} = Bonfire.Me.Accounts.signup(signup_form())
      conn = get(conn, "/signup/email/confirm/#{account.email.confirm_token}")
      assert redirected_to(conn) == "/switch-user"

      conn =
        get(
          build_conn(),
          "/signup/email/confirm/#{account.email.confirm_token}"
        )

      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#confirm-email-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_] = Floki.find(form, "button[type='submit']")
      assert [err] = Floki.find(doc, ".alert-error")
      assert Floki.text(err) =~ ~r/invalid confirmation link/i
    end
  end
end
