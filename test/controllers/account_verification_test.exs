defmodule Bonfire.UI.Me.AccountVerificationControllerTest do
  @moduledoc """
  The sudo gate: /account/confirm renders an action's description and executes it only behind fresh factor proof; /account/verify challenges for the strongest required factor, stamping the session on success and following `go`.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  use Repatch.ExUnit

  alias Bonfire.Data.Identity.Email

  @delete_mod "Bonfire.Me.SensitiveActions.DeleteAccount"
  @confirm_path "/account/confirm?action=#{@delete_mod}"

  defp fresh_proof, do: %{password: System.system_time(:millisecond)}
  defp stale_proof, do: %{password: System.system_time(:millisecond) - to_timeout(hour: 1)}

  defp passwordless_account! do
    account = fake_account!()

    Bonfire.Common.Repo.delete_all(
      import(Ecto.Query) &&
        Ecto.Query.from(c in Bonfire.Data.Identity.Credential, where: c.id == ^account.id)
    )

    Bonfire.Common.Repo.get!(Bonfire.Data.Identity.Account, account.id)
  end

  defp capture_mail do
    test_pid = self()

    Repatch.patch(Bonfire.Mailer, :send_now, [mode: :shared], fn mail, to ->
      send(test_pid, {:sudo_mail, mail, to})
      {:ok, mail}
    end)
  end

  describe "the confirm gate" do
    test "anonymous requests get the standard login redirect with go stashed including the action" do
      response = get(conn(), @confirm_path)
      assert redirected_to(response) =~ "/login"
      go = get_session(response, :go)
      assert go =~ "/account/confirm"
      assert go =~ "action="
    end

    test "logged in without fresh proof redirects to verify with go back to confirm" do
      response = conn(account: fake_account!()) |> get(@confirm_path)
      location = redirected_to(response)
      assert location =~ "/account/verify"
      assert location =~ "for="
      assert location =~ URI.encode_www_form("/account/confirm")
    end

    test "fresh proof renders the action description and confirm button" do
      response =
        conn(account: fake_account!())
        |> init_test_session(%{sudo_proof: fresh_proof()})
        |> get(@confirm_path)

      html = html_response(response, 200)
      assert html =~ "Delete your account"
      assert html =~ "sudo-confirm-form"
    end

    test "unknown and non-adopter action params error without rendering a confirm form" do
      for bad <- ["delete_account", "Elixir.Bonfire.Me.Accounts", "Nope.Nope"] do
        response =
          conn(account: fake_account!())
          |> init_test_session(%{sudo_proof: fresh_proof()})
          |> get("/account/confirm?action=#{bad}")

        html = html_response(response, 200)
        assert html =~ "not available"
        refute html =~ "sudo-confirm-form"
      end
    end
  end

  describe "the verify page" do
    test "challenges a password account with the password form" do
      response =
        conn(account: fake_account!())
        |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")

      html = html_response(response, 200)
      assert html =~ ~s(type="password")
      assert html =~ "sudo-password-form"
    end

    test "a correct password stamps the factor and follows go" do
      account = fake_account!()

      response =
        conn(account: account)
        |> post("/account/verify/password", %{
          "password" => account.credential.password,
          "for" => @delete_mod,
          "go" => "/somewhere"
        })

      assert redirected_to(response) == "/somewhere"
      assert is_integer(get_session(response, :sudo_proof)[:password])
    end

    test "a wrong password re-renders the challenge with an error" do
      response =
        conn(account: fake_account!())
        |> post("/account/verify/password", %{
          "password" => "not-the-password",
          "for" => @delete_mod,
          "go" => "/somewhere"
        })

      html = html_response(response, 200)
      assert html =~ "match"
      assert html =~ "sudo-password-form"
      refute get_session(response, :sudo_proof)[:password]
    end

    test "rate-limited password attempts keep actionable feedback" do
      Repatch.patch(Bonfire.UI.Common.RateLimit, :check, fn _, _, _, _ ->
        {:error, :rate_limited}
      end)

      response =
        conn(account: fake_account!())
        |> post("/account/verify/password", %{
          "password" => "whatever",
          "for" => @delete_mod,
          "go" => "/somewhere"
        })

      assert html_response(response, 200) =~ "Too many attempts"
    end

    test "an email challenge auto-sends once and not again while the token is outstanding" do
      capture_mail()
      account = passwordless_account!()

      conn(account: account) |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")
      assert_receive {:sudo_mail, _, _}, 1000

      conn(account: account) |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")
      refute_receive {:sudo_mail, _, _}, 200
    end

    test "resend re-mails the outstanding valid token unchanged (single-outstanding-token semantics)" do
      capture_mail()
      account = passwordless_account!()

      conn(account: account) |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")
      assert_receive {:sudo_mail, _, _}, 1000
      token_before = Bonfire.Common.Repo.get!(Email, account.id).confirm_token
      assert is_binary(token_before)

      conn(account: account)
      |> post("/account/verify/send_email", %{"for" => @delete_mod, "go" => "/somewhere"})

      assert_receive {:sudo_mail, _, _}, 1000
      assert Bonfire.Common.Repo.get!(Email, account.id).confirm_token == token_before
    end

    test "the emailed challenge links to the forgot-password route, never the guest-only signup confirmation" do
      capture_mail()
      account = passwordless_account!()

      conn(account: account) |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")
      assert_receive {:sudo_mail, mail, _}, 1000

      body = mail.html_body || mail.text_body
      assert body =~ "/login/forgot-password/"
      refute body =~ "/signup/email/confirm/"

      # verification mails say what they are and what they authorize, with the intent in the body only
      assert mail.subject =~ "Confirm it's you"
      refute mail.subject =~ "Reset your password"
      refute mail.subject =~ "Delete"
      assert body =~ "Delete your account"
    end

    test "the emailed link carries the initiating profile so redemption can restore it" do
      capture_mail()
      account = passwordless_account!()
      me = fake_user!(account)

      conn(user: me, account: account) |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")
      assert_receive {:sudo_mail, mail, _}, 1000

      body = mail.html_body || mail.text_body
      assert body =~ "as_user=#{me.id}"
    end

    test "the password challenge's reset escape emails the reset link, not the signup confirmation" do
      capture_mail()
      account = fake_account!()

      conn(account: account)
      |> post("/account/verify/send_email", %{"for" => @delete_mod, "go" => "/somewhere"})

      assert_receive {:sudo_mail, mail, _}, 1000
      body = mail.html_body || mail.text_body
      assert body =~ "/login/forgot-password/"
      refute body =~ "/signup/email/confirm/"
      assert mail.subject =~ "Confirm it's you"
      refute mail.subject =~ "Reset your password"
      assert body =~ "Delete your account"
    end

    test "a two-factor requirement challenges factors in strength order across requests" do
      Process.put(
        [:bonfire_me, Bonfire.Me.SensitiveActions.DeleteAccount, :sudo_factors],
        {:any, 2}
      )

      capture_mail()
      account = fake_account!()

      # strongest factor first: the password challenge
      response = conn(account: account) |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")
      assert html_response(response, 200) =~ "sudo-password-form"
      refute_receive {:sudo_mail, _, _}, 100

      # with :password fresh but :email not, the challenge moves to email (and auto-sends)
      response =
        conn(account: account)
        |> init_test_session(%{sudo_proof: %{password: System.system_time(:millisecond)}})
        |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")

      assert html_response(response, 200) =~ "sudo-resend-form"
      assert_receive {:sudo_mail, _, _}, 1000

      # with both fresh, the gate is met
      response =
        conn(account: account)
        |> init_test_session(%{
          sudo_proof: %{
            password: System.system_time(:millisecond),
            email: System.system_time(:millisecond)
          }
        })
        |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")

      assert redirected_to(response) == "/somewhere"
    end

    test "a met requirement redirects straight through go" do
      response =
        conn(account: fake_account!())
        |> init_test_session(%{sudo_proof: fresh_proof()})
        |> get("/account/verify?for=#{@delete_mod}&go=/somewhere")

      assert redirected_to(response) == "/somewhere"
    end

    test "a non-local go is not followed" do
      response =
        conn(account: fake_account!())
        |> init_test_session(%{sudo_proof: fresh_proof()})
        |> get("/account/verify?for=#{@delete_mod}&go=https://evil.example/phish")

      location = redirected_to(response)
      refute location =~ "evil.example"
    end
  end

  describe "the confirm POST" do
    test "fresh proof executes exactly once and shows the done message" do
      response =
        conn(account: fake_account!())
        |> init_test_session(%{sudo_proof: fresh_proof()})
        |> post(@confirm_path)

      assert html_response(response, 200) =~ "Account deletion requested"

      assert length(Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)) == 1
    end

    test "lapsed proof bounces to verify with the same go and executes nothing" do
      response =
        conn(account: fake_account!())
        |> init_test_session(%{sudo_proof: stale_proof()})
        |> post(@confirm_path)

      location = redirected_to(response)
      assert location =~ "/account/verify"
      assert location =~ URI.encode_www_form("/account/confirm")

      Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    end
  end
end
