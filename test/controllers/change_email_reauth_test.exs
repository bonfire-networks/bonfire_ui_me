defmodule Bonfire.UI.Me.ChangeEmailReauthTest do
  @moduledoc """
  Changing the account email proves who is asking: a session that merely is signed in (no fresh password or email-link proof) must not be able to swap the address, since that is the first step of taking an account over (change email, then reset the password).
  """
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Email

  defp account!, do: fake_account!() |> Bonfire.Common.Repo.preload([:email, :credential])

  defp email_of(account), do: Bonfire.Common.Repo.get!(Email, account.id).email_address

  defp change_params(old, new),
    do: %{"change_email_fields" => %{"old_email" => old, "email" => new}}

  defp new_address, do: "taken-over-#{System.unique_integer([:positive])}@example.local"

  test "a signed-in session without fresh proof cannot change the email" do
    account = account!()
    old = email_of(account)
    new = new_address()

    # no sudo_proof in the session: signed in, nothing re-entered
    conn = post(conn(account: account), "/account/email/change", change_params(old, new))

    # wanted: the address stays as it was until identity is proven
    assert email_of(account) == old
    refute email_of(account) == new
    # the request is not accepted as a plain success redirect home either
    refute conn.status in [301, 302, 303] and redirected_to(conn) == "/"
  end

  test "control: with a fresh password proof the same request changes the email" do
    account = account!()
    old = email_of(account)
    new = new_address()

    conn =
      conn(account: account)
      |> init_test_session(%{sudo_proof: %{password: System.system_time(:millisecond)}})
      |> post("/account/email/change", change_params(old, new))

    assert conn.status in [301, 302, 303]
    assert email_of(account) == new
  end

  test "control: a request that fails the old_email check leaves the email unchanged (existing behaviour)" do
    account = account!()
    old = email_of(account)

    conn =
      post(
        conn(account: account),
        "/account/email/change",
        change_params("not-my-email@example.local", new_address())
      )

    refute conn.status in [301, 302, 303]
    assert email_of(account) == old
    assert Accounts.get_by_email(old).id == account.id
  end
end
