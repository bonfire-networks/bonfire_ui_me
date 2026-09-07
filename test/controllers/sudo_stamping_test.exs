defmodule Bonfire.UI.Me.SudoStampingTest do
  @moduledoc """
  Every login path stamps the factor it earned into the session's sudo_proof factors map; and cross-account login applies logout semantics first while same-account login merges.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  use Repatch.ExUnit

  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Email

  defp account!, do: fake_account!() |> Bonfire.Common.Repo.preload([:email, :credential])

  defp login_params(account) do
    %{
      "login_fields" => %{
        "email_or_username" => account.email.email_address,
        "password" => account.credential.password
      }
    }
  end

  test "a password login stamps :password" do
    account = account!()
    conn = post(conn(), "/login", login_params(account))

    assert is_integer(get_session(conn, :sudo_proof)[:password])
    refute get_session(conn, :sudo_proof)[:email]
  end

  test "magic-link redemption in a pristine conn logs in and stamps :email" do
    Process.put([:bonfire_ui_me, :login, :passwordless_only], true)
    test_pid = self()

    Repatch.patch(Bonfire.Mailer, :send_now, [mode: :shared], fn mail, to ->
      send(test_pid, {:mail, mail, to})
      {:ok, mail}
    end)

    account = account!()

    {:ok, _, _} =
      Accounts.request_confirm_email(%{email: account.email.email_address},
        confirm_action: :login,
        go: "/somewhere",
        must_confirm?: true
      )

    token = Bonfire.Common.Repo.get!(Email, account.id).confirm_token

    # a pristine conn: the cross-device case, the redeeming browser was never logged in
    conn = get(conn(), "/login/forgot-password/#{token}?go=/somewhere")

    assert get_session(conn, :current_account_id) == account.id
    assert is_integer(get_session(conn, :sudo_proof)[:email])
    refute get_session(conn, :sudo_proof)[:password]
    assert get_session(conn, :go) =~ "/somewhere"
  end

  test "signed-in redemption on a password instance reaches the reset flow (no guest bounce) and stamps :email" do
    test_pid = self()

    Repatch.patch(Bonfire.Mailer, :send_now, [mode: :shared], fn mail, to ->
      send(test_pid, {:mail, mail, to})
      {:ok, mail}
    end)

    account = account!()

    {:ok, _, _} =
      Accounts.request_confirm_email(%{email: account.email.email_address},
        confirm_action: :forgot_password,
        go: "/somewhere",
        must_confirm?: true
      )

    token = Bonfire.Common.Repo.get!(Email, account.id).confirm_token

    conn = conn(account: account) |> get("/login/forgot-password/#{token}?go=/somewhere")

    assert redirected_to(conn) =~ "/account/password/change"
    assert get_session(conn, :resetting_password)
    assert is_integer(get_session(conn, :sudo_proof)[:email])
  end

  test "completing a password change stamps :password" do
    account = account!()

    conn =
      conn(account: account)
      |> post("/account/password/change", %{
        "change_password_fields" => %{
          "old_password" => account.credential.password,
          "password" => "a-brand-new-password",
          "password_confirmation" => "a-brand-new-password"
        }
      })

    assert conn.status in [301, 302, 303]
    assert is_integer(get_session(conn, :sudo_proof)[:password])
  end
end
