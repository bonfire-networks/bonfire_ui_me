defmodule Bonfire.UI.Me.SwitchUserMenuTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  import Phoenix.LiveViewTest

  alias Bonfire.Social.Graph.Follows

  setup do
    account = fake_account!()

    alice =
      current_user(
        Bonfire.Common.Settings.put([Bonfire.Me.Users, :show_switch_users_inline], true,
          current_user: fake_user!(account)
        )
      )

    bob = fake_user!(account)
    carl = fake_user!(account)

    conn = conn(user: alice, account: account)

    {:ok, conn: conn, alice: alice, bob: bob, carl: carl}
  end

  test "the user menu's profile switcher only loads profiles once the menu is opened, and flags the ones with unseen notifications",
       %{conn: conn, bob: bob, carl: carl} do
    # a follow from someone else lands in bob's notifications, unseen
    {:ok, _} = Follows.follow(fake_user!(), bob)

    {:ok, view, _html} = live(conn, "/dashboard")

    assert has_element?(view, "#switch_user_menu_items")
    refute has_element?(view, "[data-role=switch_user_menu_profile]")

    view |> element("#user_more_menu_links_trigger") |> render_click()

    assert has_element?(
             view,
             "a[data-role=switch_user_menu_profile][href='/switch-user/#{bob.character.username}'] [data-role=switch_user_menu_unseen]"
           )

    assert has_element?(
             view,
             "a[data-role=switch_user_menu_profile][href='/switch-user/#{carl.character.username}']"
           )

    refute has_element?(
             view,
             "a[data-role=switch_user_menu_profile][href='/switch-user/#{carl.character.username}'] [data-role=switch_user_menu_unseen]"
           )
  end

  test "without the inline setting the menu only links to the switch profile page" do
    account = fake_account!()
    alice = fake_user!(account)
    _bob = fake_user!(account)
    conn = conn(user: alice, account: account)

    {:ok, view, _html} = live(conn, "/dashboard")

    view |> element("#user_more_menu_links_trigger") |> render_click()

    assert has_element?(view, "#switch_user_menu_items a[href='/switch-user']")
    refute has_element?(view, "[data-role=switch_user_menu_profile]")
  end
end
