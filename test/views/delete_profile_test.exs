defmodule Bonfire.UI.Me.DeleteProfileTest do
  @moduledoc """
  The delete-profile action requires the account password: a wrong or missing password leaves the user intact, a correct one enqueues deletion and redirects to the deleted page.
  """
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Me.Users

  @password_label "For security purposes please enter the password of your account"
  @delete_button "Delete user & data"

  setup do
    account = fake_account!()
    alice = fake_user!(account)
    conn = conn(user: alice, account: account)
    {:ok, conn: conn, account: account, alice: alice}
  end

  describe "delete profile password gate" do
    test "refuses a wrong password and keeps the user", %{conn: conn, alice: alice} do
      conn
      |> visit("/settings/user/profile")
      |> wait_async()
      |> click_button("[data-role=open_modal]", @delete_button)
      |> fill_in(@password_label, with: "not-the-password")
      |> click_button("button[type=submit]", @delete_button)
      |> assert_has("[role=alert]", text: "details you provided")

      assert {:ok, _} = Users.by_username(alice.character.username)

      Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    end

    test "refuses an empty password and keeps the user", %{conn: conn, alice: alice} do
      conn
      |> visit("/settings/user/profile")
      |> wait_async()
      |> click_button("[data-role=open_modal]", @delete_button)
      |> click_button("button[type=submit]", @delete_button)
      |> assert_has("[role=alert]", text: "details you provided")

      assert {:ok, _} = Users.by_username(alice.character.username)

      Oban.Testing.refute_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    end

    test "proceeds with the correct password", %{conn: conn, account: account, alice: alice} do
      conn
      |> visit("/settings/user/profile")
      |> wait_async()
      |> click_button("[data-role=open_modal]", @delete_button)
      |> fill_in(@password_label, with: account.credential.password)
      |> click_button("button[type=submit]", @delete_button)
      |> assert_path("/settings/deleted/user/#{alice.id}")

      Oban.Testing.assert_enqueued(repo(), worker: Bonfire.Me.DeleteWorker)
    end
  end
end
