defmodule Bonfire.UI.Me.LoginSessionSemanticsTest do
  @moduledoc """
  Logging into a different account applies logout semantics first (prior session state, including sudo proof, is cleared; the stashed go survives); logging into the same account merges the earned factor into existing fresh ones. The login form is guest-only, so the endpoint where cross-account login actually happens is magic-link redemption.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  use Repatch.ExUnit

  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Email

  setup do
    # magic-link redemption logs the redeeming browser in on gated instances
    Process.put([:bonfire_ui_me, :login, :passwordless_only], true)
    test_pid = self()

    Repatch.patch(Bonfire.Mailer, :send_now, [mode: :shared], fn mail, to ->
      send(test_pid, {:mail, mail, to})
      {:ok, mail}
    end)

    :ok
  end

  defp account!, do: fake_account!() |> Bonfire.Common.Repo.preload([:email, :credential])

  defp login_token_for(account, go) do
    {:ok, _, _} =
      Accounts.request_confirm_email(%{email: account.email.email_address},
        confirm_action: :login,
        go: go,
        must_confirm?: true
      )

    Bonfire.Common.Repo.get!(Email, account.id).confirm_token
  end

  test "redeeming another account's link clears prior proof (logout semantics) and keeps go" do
    a = account!()
    b = account!()
    mark = System.system_time(:millisecond)
    token = login_token_for(b, "/keep-me")

    conn =
      conn(account: a)
      |> init_test_session(%{sudo_proof: %{password: mark}})
      |> get("/login/forgot-password/#{token}?go=/keep-me")

    proof = get_session(conn, :sudo_proof)
    assert is_integer(proof[:email])
    refute proof[:password]
    assert get_session(conn, :current_account_id) == b.id
    assert get_session(conn, :go) =~ "/keep-me"
  end

  test "cross-account reset-link redemption (password instance) also clears prior proof" do
    Process.put([:bonfire_ui_me, :login, :passwordless_only], false)
    a = account!()
    b = account!()
    mark = System.system_time(:millisecond)

    {:ok, _, _} =
      Accounts.request_confirm_email(%{email: b.email.email_address},
        confirm_action: :forgot_password,
        go: "/keep-me",
        must_confirm?: true
      )

    token = Bonfire.Common.Repo.get!(Email, b.id).confirm_token

    conn =
      conn(account: a)
      |> init_test_session(%{sudo_proof: %{password: mark}})
      |> get("/login/forgot-password/#{token}?go=/keep-me")

    proof = get_session(conn, :sudo_proof)
    assert is_integer(proof[:email])
    refute proof[:password]
    assert get_session(conn, :current_account_id) == b.id
    assert get_session(conn, :go) =~ "/keep-me"
  end

  test "redeeming a link whose go is account-scoped skips the profile switcher" do
    account = account!()
    go = "/account/confirm?action=Bonfire.Me.SensitiveActions.DeleteAccount"
    token = login_token_for(account, go)

    # this account has no user profile at all, the case that otherwise lands on switch-user
    conn = get(conn(), "/login/forgot-password/#{token}?go=#{URI.encode_www_form(go)}")

    assert redirected_to(conn, 303) =~ "/account/confirm"
  end

  test "redemption restores the initiating profile when the link carries a validated as param" do
    account = account!()
    me = fake_user!(account)
    go = "/account/confirm?action=Bonfire.Me.SensitiveActions.DeleteAccount"
    token = login_token_for(account, go)

    conn =
      get(
        conn(),
        "/login/forgot-password/#{token}?go=#{URI.encode_www_form(go)}&as_user=#{me.id}"
      )

    assert get_session(conn, :current_user_id) == me.id
    assert redirected_to(conn, 303) =~ "/account/confirm"
  end

  test "a foreign as param is ignored (ownership-validated)" do
    account = account!()
    other = fake_user!()
    go = "/account/confirm?action=Bonfire.Me.SensitiveActions.DeleteAccount"
    token = login_token_for(account, go)

    conn =
      get(
        conn(),
        "/login/forgot-password/#{token}?go=#{URI.encode_www_form(go)}&as_user=#{other.id}"
      )

    refute get_session(conn, :current_user_id) == other.id
    # still lands on the account-scoped go via the fallback skip
    assert redirected_to(conn, 303) =~ "/account/confirm"
  end

  test "redeeming your own link merges the earned factor with existing fresh ones" do
    a = account!()
    mark = System.system_time(:millisecond)
    token = login_token_for(a, nil)

    conn =
      conn(account: a)
      |> init_test_session(%{sudo_proof: %{password: mark}})
      |> get("/login/forgot-password/#{token}")

    proof = get_session(conn, :sudo_proof)
    assert proof[:password] == mark
    assert is_integer(proof[:email])
    assert get_session(conn, :current_account_id) == a.id
  end
end
