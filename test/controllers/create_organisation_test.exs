defmodule Bonfire.UI.Me.CreateOrganisationTest do
  @moduledoc "The organisation-profile creation flow: the type=organisation form (with label), it becoming a shared user that federates as an Organization, and step 2 (the invite-your-team view reusing the Team Profiles component)."
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  use Repatch.ExUnit
  import Tesla.Mock

  alias Bonfire.Me.SharedUsers
  alias Bonfire.Me.Fake

  setup_all do
    mock_global(fn env -> ActivityPub.Test.HttpRequestMock.request(env) end)
    :ok
  end

  describe "the create-profile form" do
    test "a personal profile does not show the organisation label field" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = get(conn, "/create-user")
      doc = floki_response(conn)
      assert [_] = Floki.find(doc, "#create-user-form")
      assert [] = Floki.find(doc, "#create-user-label")
    end

    test "?type=organisation renders the organisation profile form (with the label field)" do
      alice = fake_account!()
      conn = conn(account: alice)
      conn = get(conn, "/create-user?type=organisation")
      doc = floki_response(conn)
      assert [form] = Floki.find(doc, "#create-user-form")
      # the org-only label field is shown
      assert [_] = Floki.find(form, "#create-user-label")
      # and the profile kind is carried through on submit
      assert ["organisation"] = Floki.attribute(form, "input[name=type]", "value")
    end

    test "?type=organisation keeps the organisation form through the connected LiveView mount" do
      alice = fake_account!()
      conn = conn(account: alice)

      # `visit` does a connected mount (unlike `get`), so it catches the profile kind being lost on reconnect
      conn
      |> visit("/create-user?type=organisation")
      |> assert_has("#create-user-label")
    end
  end

  describe "creating the profile" do
    test "an organisation profile becomes a shared user (with the given label), links the creating account, and lands on step 2" do
      alice = fake_account!()
      conn = conn(account: alice)
      username = username()

      params =
        %{
          "user" => %{
            "profile" => %{"summary" => summary(), "name" => name()},
            "character" => %{"username" => username}
          },
          "type" => "organisation",
          "label" => "Rebel Alliance"
        }
        |> with_acknowledgements()

      conn = post(conn, "/create-user", params)
      # step 2: an organisation lands on the invite-your-team view (not straight to the home feed)
      assert redirected_to(conn) == "/create-user/team"

      {:ok, user} = Bonfire.Me.Users.by_username(username)

      # it federates as an Organization because it carries the shared_user mixin
      assert Bonfire.Common.URIs.shared_user?(user, preload_if_needed: true)

      user = repo().maybe_preload(user, :shared_user)
      assert e(user, :shared_user, :label, nil) == "Rebel Alliance"

      # the creating account is linked as the sole caretaker, so it can manage the org
      assert [caretaker] = SharedUsers.list_accounts(user)
      assert caretaker.id == alice.id

      # the session switches to the new org, so step 2 loads it as current_user
      assert get_session(conn, :current_user_id) == user.id

      # following the redirect renders the team view for the org (not bounced by user_required)
      recycle(conn)
      |> visit("/create-user/team")
      |> wait_async()
      |> assert_has("#create_user_team")
    end

    test "a personal profile does not become a shared user" do
      alice = fake_account!()
      conn = conn(account: alice)
      username = username()

      params =
        %{
          "user" => %{
            "profile" => %{"summary" => summary(), "name" => name()},
            "character" => %{"username" => username}
          }
        }
        |> with_acknowledgements()

      conn = post(conn, "/create-user", params)
      assert redirected_to(conn) == "/"

      {:ok, user} = Bonfire.Me.Users.by_username(username)
      refute Bonfire.Common.URIs.shared_user?(user, preload_if_needed: true)
    end
  end

  describe "choosing which of my profiles co-manages the org" do
    test "the form offers a chooser when the account already has more than one profile" do
      account = fake_account!()
      _u1 = fake_user!(account)
      _u2 = fake_user!(account)
      conn = conn(account: account)
      conn = get(conn, "/create-user?type=organisation")
      doc = floki_response(conn)
      assert [_] = Floki.find(doc, "#create-user-creator")
    end

    test "with exactly one profile there's no chooser; that profile is auto-linked" do
      account = fake_account!()
      u1 = fake_user!(account)
      conn = conn(account: account)
      conn = get(conn, "/create-user?type=organisation")
      doc = floki_response(conn)
      assert [] = Floki.find(doc, "#create-user-creator")
      assert [hidden] = Floki.find(doc, "input[name=creator_user_id]")
      assert Floki.attribute(hidden, "value") == [u1.id]
    end

    test "the chosen profile is linked as the org's first team member" do
      account = fake_account!()
      chosen = fake_user!(account)
      other = fake_user!(account)
      conn = conn(account: account)
      username = username()

      params =
        %{
          "user" => %{
            "profile" => %{"summary" => summary(), "name" => name()},
            "character" => %{"username" => username}
          },
          "type" => "organisation",
          "label" => "The A Team",
          "creator_user_id" => chosen.id
        }
        |> with_acknowledgements()

      conn = post(conn, "/create-user", params)
      assert redirected_to(conn) == "/create-user/team"

      {:ok, org} = Bonfire.Me.Users.by_username(username)

      linked =
        SharedUsers.list_linked_users(org) |> Enum.map(&e(&1, :character, :username, nil))

      assert chosen.character.username in linked
      refute other.character.username in linked
    end
  end

  describe "step 2 (invite your team)" do
    test "renders the shared invite + roster component for the org, showing the linked co-manager" do
      account = Fake.fake_account!()
      org = Fake.fake_user!(account)

      # a co-manager on a different account, invited by username -> org becomes a shared user
      member = Fake.fake_user!()

      {:ok, _} =
        SharedUsers.add_account(org, "@" <> member.character.username, %{},
          current_account: account
        )

      conn = conn(user: org, account: account)

      conn
      |> visit("/create-user/team")
      |> wait_async()
      # the same invite input the Team Profiles settings tab uses (DRY component)
      |> assert_has("#add_shared_user")
      |> assert_has("[data-role=finish_org_setup]")
      # the roster shows the invited co-manager (not the account's other personas)
      |> assert_has("#create_user_team", text: member.profile.name)
    end

    test "an org with no invited team members does not list itself (or anyone) as a member" do
      account = Fake.fake_account!()
      org = Fake.fake_user!(account)

      # make it a shared user with only the creator's account-only bootstrap link (no personas, no invites)
      SharedUsers.init_shared_user(org, %{}, current_account: account)

      conn = conn(user: org, account: account)

      conn
      |> visit("/create-user/team")
      |> wait_async()
      |> assert_has("#add_shared_user")
      # with no real co-managers the roster must not render a spurious self/"Me" row
      |> refute_has("[data-role=team_members]")
    end

    test "a team member can be invited and then removed through the UI" do
      account = Fake.fake_account!()
      org = Fake.fake_user!(account)
      creator = Fake.fake_user!(account)

      member_account = Fake.fake_account!()
      member = Fake.fake_user!(member_account)

      # the creator's account is already linked (so we're an org, authorised, and won't hit the last-member guard when removing)
      {:ok, _} =
        SharedUsers.add_account(org, "@" <> creator.character.username, %{},
          current_user: creator
        )

      conn = conn(user: org, account: account)

      session =
        conn
        |> visit("/create-user/team")
        |> wait_async()
        |> fill_in("Add team members", with: "@" <> member.character.username)
        |> click_button("Submit")
        |> wait_async()
        # the newly invited member now appears in the roster
        |> assert_has("#create_user_team", text: member.profile.name)

      # remove them via their row's Remove button (keyed by account id), and they disappear
      session
      |> click_button("[phx-value-id='#{member_account.id}']", "Remove")
      |> wait_async()
      |> refute_has("#create_user_team", text: member.profile.name)
    end
  end

  defp with_acknowledgements(params) do
    Map.merge(params, %{
      "political_consent" => "true",
      "code_of_conduct_consent" => "true"
    })
  end
end
