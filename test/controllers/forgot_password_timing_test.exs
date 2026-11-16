defmodule Bonfire.UI.Me.ForgotPasswordTimingTest do
  @moduledoc """
  A forgot-password request for a known address takes as long as one for an unknown address: the mail is not sent during the request, so response time does not tell whether an account exists.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  use Repatch.ExUnit
  @moduletag :ui

  # how long the (patched) mailer takes to hand a mail over
  @mail_ms 400

  defp submit_forgot(address) do
    started = System.monotonic_time(:millisecond)

    resp =
      post(conn(), "/login/forgot-password", %{"forgot_password_fields" => %{"email" => address}})

    {resp, System.monotonic_time(:millisecond) - started}
  end

  test "a known address does not cost the request the time of sending a mail" do
    Process.put([:bonfire_ui_me, :login, :passwordless_only], false)

    Repatch.patch(Bonfire.Mailer, :send_now, fn _mail, _to ->
      Process.sleep(@mail_ms)
      {:ok, :sent}
    end)

    account = fake_account!()

    {unknown_resp, unknown_ms} =
      submit_forgot("nobody-#{System.unique_integer([:positive])}@example.local")

    {known_resp, known_ms} = submit_forgot(account.email.email_address)

    # control: both got the same neutral answer
    assert unknown_resp.resp_body =~ "Check your inbox"
    assert known_resp.resp_body =~ "Check your inbox"

    # an unknown address does no mail work, so it is the baseline
    assert unknown_ms < @mail_ms

    assert known_ms < @mail_ms,
           "a known address took #{known_ms}ms, an unknown one #{unknown_ms}ms: the mail is sent inside the request"
  end
end
