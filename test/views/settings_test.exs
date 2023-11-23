defmodule Bonfire.UI.Me.SettingsTest do
  use Bonfire.UI.Me.ConnCase, async: false
  import Phoenix.LiveViewTest
  use Mneme

  describe "Appearance" do
    test "As a user I want to select a different theme" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"theme" => %{"instance_theme" => "dracula"}}})

      assert view
             |> element("[data-theme=dracula]")
             |> has_element?()
    end

    # FIXME: find a way to check the font
    test "As a user I want to select a different font" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"font_family" => "Luciole"}})

      assert "Luciole" ==
               view
               |> element("body")
    end

    test "As a user I want to select a different language" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_language]")
      |> render_change(%{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => "it"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("span[data-role=locale]", "it")
    end

    test "As a user I want to switch composer ui" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_composer]")
      |> render_change(%{
        "Elixir.Bonfire.UI.Common.SmartInputContainerLive" => %{
          "show_focused" => "true"
        }
      })

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("div#smart_input_container[data-focused]")
    end

    test "As a user I want to hide brand name" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_brand]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.LogoLive" => %{"only_logo" => "true"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)
      open_browser(refreshed_view)

      auto_assert false <-
                    refreshed_view
                    |> has_element?("div[data-id=logo] div[data-scope=logo_name]")
    end

    test "As a user I want to change avatar shape to square" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_avatar_shape]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"shape" => "false"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert true <-
                    refreshed_view
                    |> has_element?("div[data-scope=avatar] div[data-square]")
    end

    test "As a user I want to hide avatar from the layout" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_avatar_shape]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"shape" => "false"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      auto_assert false <-
                    refreshed_view
                    |> has_element?("div[data-scope=sticky_menu] div[data-scope=avatar]")
    end
  end
end
