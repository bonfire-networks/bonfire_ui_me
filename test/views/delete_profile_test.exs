defmodule Bonfire.UI.Me.DeleteProfileTest do
  @moduledoc "Profile deletion follows the sudo gate and authorizes the URL target against its owning account."
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Me.Users
  alias Bonfire.Me.SensitiveActions.DeleteUser

  @action "Bonfire.Me.SensitiveActions.DeleteUser"

  setup do
    account = fake_account!()
    alice = fake_user!(account)
    {:ok, account: account, alice: alice}
  end

  test "settings goes through verification and queues only the selected profile", %{account: account, alice: alice} do
    sibling = fake_user!(account)

    conn(user: alice, account: account)
    |> visit("/settings/user/profile")
    |> wait_async()
    |> click_link("#verify-delete-profile", "Continue to delete profile")
    |> assert_has("#sudo-password-form")
    |> fill_in("Your password", with: account.credential.password)
    |> click_button("#sudo-password-submit", "Verify and continue")
    |> assert_has("#sudo-title", text: "Delete your profile")
    |> click_button("#sudo-confirm-btn", "Confirm")
    |> assert_has("#sudo-title", text: "Profile deletion requested")

    assert [%{args: %{"ids" => [id]}}] = Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    assert id == alice.id
    assert {:ok, _} = Users.by_username(sibling.character.username)
    assert {:ok, _} = Bonfire.Me.Accounts.fetch_current(account.id)
  end

  test "wrong password never queues deletion", %{account: account, alice: alice} do
    conn(user: alice, account: account)
    |> visit(confirm_url(alice.id))
    |> fill_in("Your password", with: "not-the-password")
    |> click_button("#sudo-password-submit", "Verify and continue")
    |> assert_has("[role=alert]", text: "That password didn't match.", exact: false)

    Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
  end

  test "a fresh owner can delete its profile without relying on the selected profile", %{account: account, alice: alice} do
    response = verified_conn(account) |> post("/account/confirm", %{action: @action, target: alice.id})
    assert html_response(response, 200) =~ "Profile deletion requested"
    assert [%{args: %{"ids" => [id]}}] = Oban.Testing.all_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    assert id == alice.id
  end

  test "missing proof cannot execute even an owned target", %{account: account, alice: alice} do
    response = conn(account: account) |> post("/account/confirm", %{action: @action, target: alice.id})
    assert redirected_to(response) =~ "/account/verify"
    Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
  end

  test "foreign, missing and malformed targets cannot be executed", %{account: account} do
    foreign = fake_user!(fake_account!())
    for target <- [foreign.id, nil, "not-an-id", Needle.ULID.generate()] do
      assert {:error, _} = DeleteUser.execute(%{account: account, target_id: target})
    end
    Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
  end

  test "substituting a foreign target on POST refuses deletion", %{account: account, alice: alice} do
    foreign = fake_user!(fake_account!())
    browser = verified_conn(account) |> get(confirm_url(alice.id))
    assert html_response(browser, 200) =~ "sudo-confirm-form"
    response = browser |> post("/account/confirm", %{action: @action, target: foreign.id})
    assert html_response(response, 200) =~ "not available"
    Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
  end

  test "caretaker access does not permit deleting a shared profile", %{account: owner, alice: alice} do
    caretaker = fake_account!()
    caretaker_user = fake_user!(caretaker)
    {:ok, _} = Bonfire.Me.SharedUsers.add_account(alice, "@" <> caretaker_user.character.username)
    assert %{id: id} = Users.get_in_account(alice.id, caretaker.id)
    assert id == alice.id
    assert {:error, _} = DeleteUser.execute(%{account: caretaker, target_id: alice.id})
    Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    assert {:ok, _} = DeleteUser.execute(%{account: owner, target_id: alice.id})
  end

  test "confirmation names the owned profile without exposing a foreign profile", %{account: account, alice: alice} do
    response = verified_conn(account) |> get(confirm_url(alice.id))
    document = html_response(response, 200) |> Floki.parse_document!()
    assert Floki.find(document, "p.prose") |> Floki.text() =~ alice.character.username

    foreign = fake_user!(fake_account!())
    description = DeleteUser.describe(%{account: account, target_id: foreign.id})
    refute description.description =~ foreign.character.username
  end

  test "ownership is checked again after the confirmation page is rendered", %{account: account, alice: alice} do
    browser = verified_conn(account) |> get(confirm_url(alice.id))
    assert html_response(browser, 200) =~ "sudo-confirm-form"
    new_owner = fake_account!()
    repo().get!(Bonfire.Data.Identity.Accounted, alice.id)
    |> Ecto.Changeset.change(account_id: new_owner.id)
    |> repo().update!()

    response = browser |> post("/account/confirm", %{action: @action, target: alice.id})
    assert html_response(response, 200) =~ "not available"
    Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    assert {:ok, _} = DeleteUser.execute(%{account: new_owner, target_id: alice.id})
  end

  defp verified_conn(account) do
    conn(account: account)
    |> init_test_session(%{sudo_proof: %{password: System.system_time(:millisecond)}})
  end

  defp confirm_url(target), do: "/account/confirm?" <> URI.encode_query(action: @action, target: target)
end
