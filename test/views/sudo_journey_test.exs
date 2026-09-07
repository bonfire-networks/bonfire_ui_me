defmodule Bonfire.UI.Me.SudoJourneyTest do
  @moduledoc """
  The whole sudo journey as a user walks it: settings → confirm page → bounced to verify → password challenge → back on confirm → execute → done, with the deletion queued exactly once.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  use Repatch.ExUnit

  setup do
    account = fake_account!()
    me = fake_user!(account)
    conn = conn(user: me, account: account)
    {:ok, conn: conn, account: account, me: me}
  end

  test "deleting the account end to end via the sudo gate", %{conn: conn, account: account} do
    conn
    |> visit("/settings/account")
    |> wait_async()
    # the entry point links to the confirm page, which bounces through verify while proof is stale
    |> click_link("#verify-delete-account", "Continue to delete account")
    |> assert_has("#sudo-password-form")
    |> fill_in("Your password", with: account.credential.password)
    |> click_button("#sudo-password-submit", "Verify and continue")
    # proof is fresh now, so we land back on the confirm page showing the action
    |> assert_has("#sudo-title", text: "Delete your account")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Account deletion requested")

    assert length(Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)) == 1
  end

  test "forgotten password: the reset escape under the form recovers the journey", %{conn: conn} do
    capture_mail()

    session =
      conn
      |> visit("/settings/account")
      |> wait_async()
      |> click_link("#verify-delete-account", "Continue to delete account")
      |> assert_has("#sudo-password-form")
      |> click_button("#sudo-reset-btn", "Can't remember it? Email me a reset link")
      |> assert_has("#sudo-resend-form")

    session
    |> visit(emailed_link())
    |> fill_in("New password", with: "a-brand-new-password")
    |> fill_in("Confirm new password", with: "a-brand-new-password")
    |> click_button("Submit")
    # completing the reset stamps :password and the stashed go returns us to the confirm page
    |> assert_has("#sudo-title", text: "Delete your account")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Account deletion requested")

    assert length(Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)) == 1
  end

  test "email as the required factor: the emailed link completes the journey", %{conn: conn} do
    # the process-override key is the module's config path prefixed with its OTP app
    Process.put([:bonfire_me, Bonfire.Me.SensitiveActions, :factor_strength], [:email])
    capture_mail()

    session =
      conn
      |> visit("/settings/account")
      |> wait_async()
      |> click_link("#verify-delete-account", "Continue to delete account")
      # with password out of the strength order, the challenge is email and auto-sends on render
      |> assert_has("#sudo-resend-form")

    session
    |> visit(emailed_link())
    |> fill_in("New password", with: "a-brand-new-password")
    |> fill_in("Confirm new password", with: "a-brand-new-password")
    |> click_button("Submit")
    # redemption stamped :email, which is the whole requirement here; go brings us back
    |> assert_has("#sudo-title", text: "Delete your account")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Account deletion requested")

    assert length(Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)) == 1
  end

  test "a two-factor requirement walks both challenges end to end", %{
    conn: conn,
    account: account
  } do
    Process.put(
      [:bonfire_me, Bonfire.Me.SensitiveActions.DeleteAccount, :sudo_factors],
      {:any, 2}
    )

    capture_mail()

    session =
      conn
      |> visit("/settings/account")
      |> wait_async()
      |> click_link("#verify-delete-account", "Continue to delete account")
      # strongest first: the password challenge
      |> assert_has("#sudo-password-form")
      |> fill_in("Your password", with: account.credential.password)
      |> click_button("#sudo-password-submit", "Verify and continue")
      # one factor down, the gate is still unmet, so we bounce into the email challenge
      |> assert_has("#sudo-resend-form")

    session
    |> visit(emailed_link())
    |> fill_in("New password", with: "a-brand-new-password")
    |> fill_in("Confirm new password", with: "a-brand-new-password")
    |> click_button("Submit")
    # redemption stamped :email and the reset re-stamped :password: both fresh, requirement met
    |> assert_has("#sudo-title", text: "Delete your account")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Account deletion requested")

    assert length(Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)) == 1
  end

  defp capture_mail do
    test_pid = self()

    Repatch.patch(Bonfire.Mailer, :send_now, [mode: :shared], fn mail, to ->
      send(test_pid, {:sudo_mail, mail, to})
      {:ok, mail}
    end)
  end

  defp emailed_link do
    assert_receive {:sudo_mail, mail, _}, 1000
    body = mail.html_body || mail.text_body
    [url] = Regex.run(~r{/login/forgot-password/[^"'\s]+}, body)
    String.replace(url, "&amp;", "&")
  end
end
