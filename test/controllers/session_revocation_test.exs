defmodule Bonfire.UI.Me.SessionRevocationTest do
  @moduledoc """
  Changing or resetting the password ends the account's other signed-in sessions, so a stolen or forgotten session does not outlive the credential it was opened with.
  """
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Email

  @new_password "a-brand-new-password"
  # an account-required page that renders for a signed-in account and bounces guests to /login
  @page "/account/password/change"

  defp account!, do: fake_account!() |> Bonfire.Common.Repo.preload([:email, :credential])

  defp signed_in?(conn) do
    conn = get(conn, @page)
    conn.status == 200
  end

  defp login(account) do
    conn =
      post(conn(), "/login", %{
        "login_fields" => %{
          "email_or_username" => account.email.email_address,
          "password" => account.credential.password
        }
      })

    assert get_session(conn, :current_account_id) == account.id
    recycle(conn)
  end

  test "changing the password in one session signs the other session out" do
    account = account!()
    session_a = login(account)
    session_b = login(account)

    # control: both sessions load the page before the change
    assert signed_in?(session_a)
    assert signed_in?(session_b)

    changed =
      post(session_a, "/account/password/change", %{
        "change_password_fields" => %{
          "old_password" => account.credential.password,
          "password" => @new_password,
          "password_confirmation" => @new_password
        }
      })

    # control: the change itself went through
    assert changed.status in [301, 302, 303]
    assert Accounts.login_valid?(account.id, @new_password)

    # wanted: the other session no longer loads a signed-in page
    refute signed_in?(session_b)
  end

  test "resetting the password signs the other session out" do
    Process.put([:bonfire_ui_me, :login, :passwordless_only], false)
    account = account!()
    other_session = login(account)

    assert signed_in?(other_session)

    {:ok, _, requested} =
      Accounts.request_confirm_email(%{email: account.email.email_address},
        confirm_action: :forgot_password,
        must_confirm?: true
      )

    # the emailed token; the database only holds its hash
    token = requested.email.confirm_token

    redeemed = post(conn(), "/login/forgot-password/#{token}")
    assert get_session(redeemed, :resetting_password)

    changed =
      redeemed
      |> recycle()
      |> post("/account/password/change", %{
        "change_password_fields" => %{
          "password" => @new_password,
          "password_confirmation" => @new_password
        }
      })

    # control: the reset itself went through
    assert changed.status in [301, 302, 303]
    assert Accounts.login_valid?(account.id, @new_password)

    # wanted: the session opened before the reset no longer loads a signed-in page
    refute signed_in?(other_session)
  end
end
