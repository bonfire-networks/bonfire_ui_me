defmodule Bonfire.UI.Me.ChangePasswordController.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  import Ecto.Query
  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Data.Identity.Credential

  @new_password "a-brand-new-password"

  # A passwordless / magic-link account has no credential row at all (password_hash is NOT NULL),
  # so simulate one by removing the credential a normal fixture creates. Reload from the DB afterwards
  # so the in-memory struct reflects the now-missing credential (Repo.preload won't refetch a loaded assoc).
  defp remove_password!(account) do
    repo().delete_all(from(c in Credential, where: c.id == ^account.id))
    repo().get!(Account, account.id)
  end

  defp fresh(id), do: repo().get!(Account, id)

  defp change_password_params(extra \\ %{}) do
    %{
      "change_password_fields" =>
        Map.merge(
          %{"password" => @new_password, "password_confirmation" => @new_password},
          extra
        )
    }
  end

  test "a passwordless account can set a password without providing a current one" do
    account = fake_account!() |> remove_password!()
    # precondition: the fixture really is passwordless (else the test wouldn't exercise the path)
    refute Accounts.account_has_password?(account)

    conn = conn(account: account)
    conn = post(conn, "/account/password/change", change_password_params())

    # success redirects home
    assert conn.status in [301, 302, 303]
    # and the account now has a password...
    assert Accounts.account_has_password?(fresh(account.id))
    # ...that is actually the one we set (i.e. it can be used to log in) — the real proof
    assert Accounts.login_valid?(account.id, @new_password)
    refute Accounts.login_valid?(account.id, "not-the-password")
  end

  test "an account with a password still requires the current password" do
    account = fake_account!()
    # precondition
    assert Accounts.account_has_password?(account)

    conn = conn(account: account)
    # no old_password supplied
    conn = post(conn, "/account/password/change", change_password_params())

    # must NOT succeed: the page is re-rendered with an error rather than redirecting home
    refute conn.status in [301, 302, 303]
    assert Accounts.account_has_password?(fresh(account.id))
  end
end
