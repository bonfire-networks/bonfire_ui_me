defmodule Bonfire.UI.Me.AccountVerificationControllerTest do
  use Bonfire.UI.Me.ConnCase, async: false
  use Repatch.ExUnit
  alias Bonfire.Me.SensitiveActions, as: Actions

  test "starting without a login explains that sign-in is required" do
    for response <- [get(conn(), "/account/verify/new/delete_account"), post(conn(), "/account/verify/start/delete_account")] do
      assert html_response(response, 200) =~ "Sign in to continue"
      refute html_response(response, 200) =~ "This request is no longer available"
    end
  end

  test "request creation and email redemption preserve rate-limit feedback" do
    Repatch.patch(Bonfire.UI.Common.RateLimit, :check, fn _, _, _, _ ->
      {:error, :rate_limited}
    end)
    account = fake_account!()
    response = conn(account: account) |> post("/account/verify/start/delete_account")
    assert html_response(response, 200) =~ "Too many attempts"
    refute html_response(response, 200) =~ "This request is no longer available"

    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    path = "/account/verify/#{pending.id}"
    browser = conn() |> get(path <> "/email", %{"token" => token})
    browser = browser |> post(path <> "/redeem")
    assert html_response(browser, 200) =~ "Too many attempts"
    refute get_session(browser, :sudo_proof)
    assert {:ok, _} = Actions.redeem(pending.id, token, nil)
  end

  test "the introduction supplies an explicit absent pending request to the action" do
    Repatch.patch(Bonfire.Me.SensitiveActions.DeleteAccount, :describe, fn %{account: account, pending: nil} ->
      assert account.id
      %{title: "Introduction", description: "No pending request yet", success: %{title: "Done", description: "Queued"}}
    end)

    conn(account: fake_account!())
    |> visit("/account/verify/new/delete_account")
    |> assert_has("p", text: "No pending request yet")
  end

  test "expired anonymous proof explains recovery without executing the request" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    path = "/account/verify/#{pending.id}"
    browser = conn() |> get(path <> "/email", %{"token" => token})
    browser = browser |> post(path <> "/redeem")
    expired_proof = Map.put(get_session(browser, :sudo_proof), "at", System.system_time(:second) - 301)
    browser = conn() |> init_test_session(%{sudo_proof: expired_proof})

    for response <- [get(browser, path), post(browser, path <> "/confirm")] do
      document = html_response(response, 200) |> Floki.parse_document!()
      assert Floki.find(document, "h1") |> Floki.text() =~ "Verification required"
      assert Floki.text(document) =~ "Return to the browser where you started and request another email"
      assert Floki.attribute(document, "#verification-back", "href") == ["/"]
      assert Floki.find(document, "#verification-confirm-form") == []
      refute get_session(response, :current_account_id)
    end

    assert {:ok, _} = Actions.fetch(pending.id)
    assert {:error, :invalid_link} = Actions.redeem(pending.id, token, nil)
    assert {:ok, _} = Actions.issue_email(pending.id, account.id)
  end

  test "cancelling offers the homepage to both the owner and an anonymous recipient" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    response = conn(account: account) |> post("/account/verify/#{pending.id}/cancel")
    document = html_response(response, 200) |> Floki.parse_document!()
    assert Floki.find(document, "h1") |> Floki.text() =~ "Request cancelled"
    assert Floki.attribute(document, "#verification-back", "href") == ["/"]
    assert get_session(response, :current_account_id) == account.id
    assert {:error, :expired} = Actions.fetch(pending.id)

    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    path = "/account/verify/#{pending.id}"
    browser = conn() |> get(path <> "/email", %{"token" => token})
    browser = browser |> post(path <> "/redeem")
    browser = browser |> post(path <> "/cancel")
    document = html_response(browser, 200) |> Floki.parse_document!()
    assert Floki.find(document, "h1") |> Floki.text() =~ "Request cancelled"
    assert Floki.attribute(document, "#verification-back", "href") == ["/"]
    refute get_session(browser, :sudo_proof)
    refute get_session(browser, :current_account_id)
    assert {:error, :expired} = Actions.fetch(pending.id)
  end

  test "unavailable requests offer the homepage regardless of browser session" do
    conn()
    |> visit("/account/verify/invalid")
    |> assert_has("a#verification-back[href='/']", text: "Go to homepage")

    conn(account: fake_account!())
    |> visit("/account/verify/invalid")
    |> assert_has("a#verification-back[href='/']", text: "Go to homepage")
  end

  test "email landing redirects prevent caching and referrer leakage" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    response = conn() |> get("/account/verify/#{pending.id}/email", %{"token" => "test-token"})
    assert response.status == 302
    assert get_resp_header(response, "cache-control") == ["no-store"]
    assert get_resp_header(response, "referrer-policy") == ["no-referrer"]
    assert Phoenix.Logger.filter_values(%{"token" => "test-token"}) == %{"token" => "[FILTERED]"}
  end

  test "email delivery uses a separate token and limits repeated sends" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    test_pid = self()
    Repatch.patch(Bonfire.Mailer, :send_now, fn mail, to ->
      send(test_pid, {:verification_mail, mail, to})
      {:ok, mail}
    end)
    path = "/account/verify/#{pending.id}/email"
    response = conn(account: account) |> post(path)
    assert html_response(response, 200) =~ "Check your email"
    assert_receive {:verification_mail, mail, address}
    assert address == account.email.email_address
    assert mail.text_body =~ "Delete your account"
    assert mail.text_body =~ "/account/verify/#{pending.id}/email?token="
    assert mail.html_body =~ "Review verification request"
    fresh_email = repo().get!(Bonfire.Data.Identity.Email, account.id)
    assert fresh_email.confirmed_at == account.email.confirmed_at

    response = conn(account: account) |> post(path)
    assert html_response(response, 200) =~ "Too many attempts"
    refute_receive {:verification_mail, _, _}
  end

  test "password verification reaches confirmation and rejects an incorrect password" do
    account = fake_account!()
    {:ok, _} = Bonfire.Me.Accounts.change_password(account,
      %{"password" => "a-long-test-password", "password_confirmation" => "a-long-test-password"},
      resetting_password: true)
    {:ok, pending} = Actions.create(account, "delete_account")
    path = "/account/verify/#{pending.id}/password"
    browser = conn(account: account) |> post(path, %{"verification" => %{"password" => "incorrect"}})
    refute get_session(browser, :sudo_proof)
    assert html_response(browser, 200) =~ "That password"
    document = html_response(browser, 200) |> Floki.parse_document!()
    assert Floki.attribute(document, "#verification-password", "aria-describedby") == ["verification-error"]
    browser = browser |> post(path, %{"verification" => %{"password" => "a-long-test-password"}})
    assert get_session(browser, :sudo_proof)["account_id"] == account.id
    browser = browser |> get(redirected_to(browser))
    assert html_response(browser, 200) =~ "verification-confirm-form"
  end

  test "a signed-in account can reach the real verification form" do
    account = fake_account!()
    conn(account: account)
    |> visit("/account/verify/new/delete_account")
    |> click_button("Continue")
    |> assert_has("h1", text: "Verify it’s you")
    |> assert_has("button", text: "Email me a verification link")
  end

  test "an email link verifies only the receiving browser and confirmation is separate" do
    Oban.Testing.with_testing_mode(:manual, fn ->
      account = fake_account!()
      {:ok, pending} = Actions.create(account, "delete_account")
      {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
      path = "/account/verify/#{pending.id}"

      browser = conn() |> get(path <> "/email", %{"token" => token})
      assert redirected_to(browser) == path
      refute get_session(browser, :sudo_proof)
      assert {:ok, _} = Actions.fetch(pending.id)

      browser = browser |> get(path)
      assert html_response(browser, 200) =~ "verification-redeem"
      browser = browser |> post(path <> "/redeem")
      assert get_session(browser, :sudo_proof)["account_id"] == account.id
      refute get_session(browser, :current_account_id)
      assert {:ok, _} = Actions.fetch(pending.id)

      original = conn(account: account) |> get(path)
      assert html_response(original, 200) =~ "verification-email-form"
      refute html_response(original, 200) =~ "id=\"verification-confirm-form\""

      browser = browser |> get(path)
      assert html_response(browser, 200) =~ "verification-confirm-form"
      browser = browser |> post(path <> "/confirm")
      assert html_response(browser, 200) =~ "Account deletion requested"
      document = html_response(browser, 200) |> Floki.parse_document!()
      assert Floki.attribute(document, "#verification-back", "href") == ["/"]
      assert Floki.find(document, "#verification-back") |> Floki.text() == "Go to homepage"
      assert {:error, :expired} = Actions.fetch(pending.id)
      browser = browser |> post(path <> "/confirm")
      assert html_response(browser, 200) =~ "This request is no longer available"
    end)
  end

  test "another signed-in account cannot redeem or confirm the request" do
    account = fake_account!()
    other = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    {:ok, {_, _, token}} = Actions.issue_email(pending.id, account.id)
    path = "/account/verify/#{pending.id}"
    browser = conn(account: other) |> get(path <> "/email", %{"token" => token})
    browser = browser |> get(path)
    assert html_response(browser, 200) =~ "different account"
    browser = browser |> post(path <> "/redeem")
    refute get_session(browser, :sudo_proof)
    assert {:ok, _} = Actions.redeem(pending.id, token, nil)
    assert {:error, :needs_reauth} = Actions.confirm(pending.id, nil, other.id)
  end

  test "unverified direct confirmation cannot enqueue deletion" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    response = conn(account: account) |> post("/account/verify/#{pending.id}/confirm")
    assert html_response(response, 200) =~ "verification-email-form"
    assert {:ok, _} = Actions.fetch(pending.id)
  end

  test "login starts freshness and switching profiles does not extend it" do
    account = fake_account!()
    user = fake_user!(account)
    browser = Bonfire.UI.Me.LoginController.logged_in(account, nil, conn(account: account))
    proof = get_session(browser, :sudo_proof)
    assert proof["account_id"] == account.id
    assert abs(System.system_time(:second) - proof["at"]) < 5

    old_proof = %{proof | "at" => System.system_time(:second) - 600}
    browser = conn(account: account)
      |> init_test_session(%{sudo_proof: old_proof})
      |> get("/switch-user/#{user.character.username}")
    assert get_session(browser, :current_user_id) == user.id
    assert get_session(browser, :sudo_proof) == old_proof
  end

  test "fresh login proof skips the gate but still requires final confirmation" do
    account = fake_account!()
    {:ok, pending} = Actions.create(account, "delete_account")
    response = conn(account: account)
      |> init_test_session(%{sudo_proof: %{"account_id" => account.id, "at" => System.system_time(:second)}})
      |> get("/account/verify/#{pending.id}")
    assert html_response(response, 200) =~ "verification-confirm-form"
    assert {:ok, _} = Actions.fetch(pending.id)
  end
end
