defmodule Bonfire.UI.Me.EmailBombTest do
  @moduledoc """
  Anyone can ask for a reset, sign-in or confirmation email for any address. The per-IP throttle does not stop many IPs flooding one inbox, so each recipient address has its own cap (10 per hour) on those emails, whichever endpoint asked for them. Asking again past the cap still gets the usual neutral answer, but no mail goes out.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  import Swoosh.TestAssertions
  @moduletag :ui

  @cap 10
  @attempts 14

  defp from_ip(n), do: %{conn() | remote_ip: {203, 0, 113, n}}

  # `wait` is how long to wait for another mail: reset and sign-in mails are sent in the background
  defp drain_emails(count \\ 0, wait \\ 0) do
    receive do
      {:email, _} -> drain_emails(count + 1, wait)
    after
      wait -> count
    end
  end

  # asks `fun` for an email to `address` from @attempts different IPs, returns how many emails were sent
  defp request_from_many_ips(address, fun) do
    drain_emails()

    for n <- 1..@attempts do
      fun.(from_ip(n), address)
    end

    drain_emails(0, 500)
  end

  defp forgot_password(conn, address),
    do: post(conn, "/login/forgot-password", %{"forgot_password_fields" => %{"email" => address}})

  defp login_link(conn, address),
    do: post(conn, "/login/email", %{"login_fields" => %{"email_or_username" => address}})

  defp graphql(conn, query) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/api/graphql", Jason.encode!(%{query: query}))
  end

  defp request_reset_graphql(conn, address),
    do: graphql(conn, ~s|mutation { requestResetPassword(email: "#{address}") }|)

  defp request_confirm_graphql(conn, address),
    do: graphql(conn, ~s|mutation { requestConfirmEmail(email: "#{address}") }|)

  setup do
    Process.put([:bonfire_ui_me, :login, :passwordless_only], false)
    :ok
  end

  describe "forgot-password" do
    test "many IPs asking for one address get at most the cap in emails" do
      account = fake_account!()
      address = account.email.email_address

      sent = request_from_many_ips(address, &forgot_password/2)

      # control: mail does go out
      assert sent > 0
      assert sent <= @cap, "#{sent} reset emails went to one address, the cap is #{@cap}"
    end

    test "another address still gets its email after the first hit the cap" do
      flooded = fake_account!()
      request_from_many_ips(flooded.email.email_address, &forgot_password/2)

      other = fake_account!()
      drain_emails()
      forgot_password(from_ip(200), other.email.email_address)

      address = other.email.email_address
      assert_receive {:email, %{to: [{_, ^address}]}}, 2_000
    end
  end

  describe "sign-in link" do
    test "many IPs asking for one address get at most the cap in emails" do
      Process.put([:bonfire_ui_me, :login, :passwordless_only], true)
      account = fake_account!()

      sent = request_from_many_ips(account.email.email_address, &login_link/2)

      assert sent > 0
      assert sent <= @cap, "#{sent} sign-in emails went to one address, the cap is #{@cap}"
    end
  end

  describe "GraphQL" do
    test "requestResetPassword from many IPs gets at most the cap in emails" do
      account = fake_account!()

      sent = request_from_many_ips(account.email.email_address, &request_reset_graphql/2)

      assert sent > 0
      assert sent <= @cap, "#{sent} reset emails went to one address, the cap is #{@cap}"
    end

    test "requestConfirmEmail from many IPs gets at most the cap in emails" do
      account = fake_account!(%{}, must_confirm?: true)

      sent = request_from_many_ips(account.email.email_address, &request_confirm_graphql/2)

      assert sent > 0
      assert sent <= @cap, "#{sent} confirmation emails went to one address, the cap is #{@cap}"
    end
  end
end
