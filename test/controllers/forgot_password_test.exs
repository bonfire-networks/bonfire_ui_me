defmodule Bonfire.UI.Me.ForgotPasswordController.Test do
  # Tests the controller's neutral-response guarantee: it never reveals whether
  # an email exists or whether a magic link was sent.
  use Bonfire.UI.Me.ConnCase, async: true

  defp submit_forgot(email) do
    post(conn(), "/login/forgot-password", %{"forgot_password_fields" => %{"email" => email}})
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

  test "blank email does not show the success state" do
    resp = submit_forgot("")
    refute resp.resp_body =~ "forgot-password-sent"
  end
end
