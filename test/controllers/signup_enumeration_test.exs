defmodule Bonfire.UI.Me.SignupEnumerationTest do
  @moduledoc """
  Signing up with an address that already has an account answers exactly like signing up with a fresh one (the "check your email" page), so nobody can tell from the page whether a person has an account here. The existing owner is told by email that they already have an account and where to log in.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  defp signup(address, password \\ nil) do
    credential = if password, do: %{"credential" => %{"password" => password}}, else: %{}

    post(conn(), "/signup", %{
      "account" => Map.merge(%{"email" => %{"email_address" => address}}, credential)
    })
  end

  defp drain_emails(acc \\ []) do
    receive do
      {:email, mail} -> drain_emails([mail | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  setup do
    Bonfire.Me.Fake.clear_caches()
    # forces email confirmation, as on a real instance
    System.put_env("INVITE_KEY_EMAIL_CONFIRMATION_BYPASS", "test_bypass_key")
    on_exit(fn -> System.delete_env("INVITE_KEY_EMAIL_CONFIRMATION_BYPASS") end)

    # a first account, so confirmation is required for the next ones
    existing = fake_account!()
    {:ok, existing: existing}
  end

  test "an address with a confirmed account gets the same page and status as a fresh one", %{
    existing: existing
  } do
    fresh = signup(email(), password())

    # control: a fresh signup shows the check-email state
    assert [_] = Floki.find(floki_response(fresh), "#signup_success")

    taken = signup(existing.email.email_address, password())

    assert taken.status == fresh.status
    doc = floki_response(taken)
    assert [_] = Floki.find(doc, "#signup_success")
    assert [] = Floki.find(doc, "#signup-form")
    refute Floki.text(doc) =~ ~r/already (been )?taken|already (registered|exists)/i
  end

  test "the existing owner is emailed that they already have an account", %{existing: existing} do
    drain_emails()
    signup(existing.email.email_address, password())

    mails = drain_emails()

    owner_mails =
      Enum.filter(mails, &Enum.any?(&1.to, fn {_, to} -> to == existing.email.email_address end))

    assert Enum.any?(owner_mails, fn mail ->
             (mail.text_body || "") <> (mail.html_body || "") =~ ~r/already have an account/i
           end)
  end

  test "a fresh address gets only the confirmation email, none saying it has an account" do
    drain_emails()
    address = email()
    signup(address, password())

    mails = drain_emails()
    assert Enum.any?(mails, &Enum.any?(&1.to, fn {_, to} -> to == address end))

    refute Enum.any?(mails, fn mail ->
             (mail.text_body || "") <> (mail.html_body || "") =~ ~r/already have an account/i
           end)
  end

  test "a bad password still shows its own error, not the check-email page" do
    doc = signup(email()) |> floki_response()

    assert [signup] = Floki.find(doc, "#signup")
    assert Floki.text(signup) =~ "error occurred"
    assert [] = Floki.find(doc, "#signup_success")
  end
end
