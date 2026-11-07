defmodule Bonfire.UI.Me.SettingsTest do
  use Bonfire.UI.Me.ConnCase, async: false
  use Mneme
  import Phoenix.LiveViewTest
  # alias Bonfire.Files.Simulation, as: FakeFiles

  alias Bonfire.Posts
  alias Bonfire.Social.Boosts
  alias Bonfire.Social.Likes
  alias Bonfire.Social.Graph.Follows
  alias Bonfire.Common.Config

  setup_all do
    orig1 = Config.get(:pagination_hard_max_limit)

    orig2 = Config.get(:default_pagination_limit)

    Config.put(:pagination_hard_max_limit, 10)

    Config.put(:default_pagination_limit, 10)

    on_exit(fn ->
      Config.put(:pagination_hard_max_limit, orig1)

      Config.put(:default_pagination_limit, orig2)
    end)
  end

  setup do
    account = fake_account!()
    alice = fake_user!(account)
    conn = conn(user: alice, account: account)
    {:ok, conn: conn, account: account, alice: alice}
  end

  describe "Appearance" do
    test "As a user I can revert my theme override to follow the instance theme" do
      account = fake_account!()
      alice = fake_user!(account)

      # alice overrode the instance theme with her own mode + light theme name
      assert {:ok, _} =
               Bonfire.Common.Settings.put([:ui, :theme, :preferred], :dark,
                 current_user: alice,
                 scope: :user
               )

      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"

      conn
      |> visit(next)
      |> assert_has("#theme-settings-user-dark-button .badge", text: "Active")
      |> click_button("#theme-settings-user-follow-button", "Follow instance theme")

      # re-visit for fresh server state: her override is gone, following is the default
      conn
      |> visit(next)
      |> assert_has("#theme-settings-user-follow-button .badge", text: "Active")
      |> refute_has("#theme-settings-user-dark-button .badge")
    end

    test "As a new user I follow the instance theme by default" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)

      conn
      |> visit("/settings/user/preferences/appearance")
      |> assert_has("#theme-settings-user-follow-button .badge", text: "Active")
      |> refute_has("#theme-settings-user-system-button .badge")
    end

    test "As a user I can choose the system theme, even when the instance's dark theme is a stale name" do
      # an instance configured with a dark theme that no longer exists (no CSS is compiled for it)
      original = Config.get([:ui, :theme, :instance_theme])
      Config.put([:ui, :theme, :instance_theme], "bonfire")
      on_exit(fn -> Config.put([:ui, :theme, :instance_theme], original) end)

      known_themes = Config.get([:ui, :themes_dark], []) ++ Config.get([:ui, :themes_light], [])
      refute "bonfire" in known_themes

      account = fake_account!()
      alice = fake_user!(account)

      # alice first chose a fixed light theme, so choosing system is a real change
      assert {:ok, _} =
               Bonfire.Common.Settings.put([:ui, :theme, :preferred], :light,
                 current_user: alice,
                 scope: :user
               )

      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"

      conn
      |> visit(next)
      |> assert_has("#theme-settings-user-light-button .badge", text: "Active")
      |> click_button("#theme-settings-user-system-button", "Use system")
      |> unwrap(fn view ->
        # the page switches to following the device, with two existing themes to switch between
        assert_push_event(view, "set_theme", %{theme: "system", light: light, dark: dark})
        assert light in known_themes
        assert dark in known_themes
        render(view)
      end)

      # re-visit for fresh server state: system is now her saved choice
      conn
      |> visit(next)
      |> assert_has("#theme-settings-user-system-button .badge", text: "Active")
      |> refute_has("#theme-settings-user-light-button .badge")

      # and the page is rendered in system mode, with two existing themes to switch between
      html = conn |> get(next) |> html_response(200)
      [root] = html |> Floki.parse_document!() |> Floki.find("html")
      assert Floki.attribute(root, "data-theme-mode") == ["system"]
      assert [light] = Floki.attribute(root, "data-theme-light")
      assert [dark] = Floki.attribute(root, "data-theme-dark")
      assert light in known_themes
      assert dark in known_themes
    end

    test "the theme mode buttons don't submit the settings form they sit in", %{conn: conn} do
      # a button without a type submits its form, and this form only has phx-change, so the browser would reload the page
      session = visit(conn, "/settings/user/preferences/appearance")

      for mode <- ~w(follow dark light system custom) do
        assert_has(session, "form #theme-settings-user-#{mode}-button[type=button]")
      end
    end

    test "A new user's pages use the system theme by default" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)

      html = conn |> get("/settings/user/preferences/appearance") |> html_response(200)
      [root] = html |> Floki.parse_document!() |> Floki.find("html")
      assert Floki.attribute(root, "data-theme-mode") == ["system"]
    end

    test "the custom editor renders every supported colour as inherited", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings/user/preferences/appearance")

      view
      |> element("#theme-settings-user-custom-button")
      |> render_click()

      swatches =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("#theme-settings-user-custom-themes [data-color]")

      assert length(swatches) == 20

      inherited_labels =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("#theme-settings-user-custom-themes span.font-mono.uppercase")

      assert length(inherited_labels) == 20
      assert Enum.all?(inherited_labels, &(Floki.text(&1) |> String.trim() == "Inherited"))

      view
      |> element("#theme-settings-user-key-primary button[data-role=open_modal]")
      |> render_click()

      document =
        view
        |> render()
        |> Floki.parse_fragment!()

      [editor] = Floki.find(document, "[data-color-key=color-primary]")
      [base_theme] = Floki.attribute(document, "#theme-settings-user-custom-themes", "data-theme")

      assert Floki.attribute(editor, "phx-hook") ==
               ["Bonfire.UI.Common.CustomThemeColourLive#ColourPicker"]

      assert Floki.attribute(editor, "data-saved-color") in [[], [""]]
      assert Floki.attribute(editor, "data-theme") == [base_theme]
      assert Floki.attribute(editor, "label", "for") == ["theme-settings-user-input-primary"]

      assert Floki.attribute(editor, "hex-input input", "id") == [
               "theme-settings-user-input-primary"
             ]

      assert Floki.text(editor) =~ "Inherited from #{base_theme}"
      refute view |> has_element?("[data-color-key=color-primary] button[id$='-reset-primary']")
    end

    test "a stored custom colour exposes its individual reset control", %{
      conn: conn,
      alice: alice
    } do
      assert {:ok, %{__context__: %{current_user: alice}}} =
               Bonfire.Common.Settings.put([:ui, :theme, :preferred], :custom,
                 current_user: alice,
                 scope: :user
               )

      assert {:ok, %{__context__: %{current_user: _alice}}} =
               Bonfire.Common.Settings.put_raw(
                 [:ui, :theme, :custom, "color-primary"],
                 "#123456",
                 current_user: alice,
                 scope: :user
               )

      {:ok, view, _html} = live(conn, "/settings/user/preferences/appearance")

      view
      |> element("#theme-settings-user-key-primary button[data-role=open_modal]")
      |> render_click()

      assert view
             |> has_element?(
               "[data-color-key=color-primary][data-saved-color='#123456'] #theme-settings-user-reset-primary"
             )
    end

    test "custom radius changes apply immediately and can return to the base theme", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings/user/preferences/appearance")

      view
      |> element("#theme-settings-user-custom-button")
      |> render_click()

      assert_push_event(view, "set_custom_theme", %{style: ""})

      view
      |> element("#theme-settings-user-radius-box-0_5rem")
      |> render_click()

      assert_push_event(view, "set_custom_theme", %{style: "--radius-box: 0.5rem;"})
      assert has_element?(view, "#theme-settings-user-radius-box-0_5rem[checked]")

      view
      |> element("#theme-settings-user-radius-box-inherited")
      |> render_click()

      assert_push_event(view, "set_custom_theme", %{style: ""})
      assert has_element?(view, "#theme-settings-user-radius-box-inherited[checked]")
    end

    test "As a user I want to select a different font" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"font_family" => "Luciole"}})

      # force a refresh
      {:ok, _refreshed_view, html} = live(conn, next)

      assert html =~ "fonts/luciole.css"
      # the default Inter font CSS should not be loaded after switching
      refute html =~ "fonts/inter-latin.css"
      # the CSS variable should reflect the chosen font name
      assert html =~ ~s|--font-sans: "Luciole"|
    end

    test "As a user, the chosen font is reflected in the page <head> after a fresh load" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{"ui" => %{"font_family" => "OpenDyslexic"}})

      # simulate a hard refresh with a NEW conn for the same user
      fresh_conn = conn(user: alice, account: account)
      {:ok, _view, html} = live(fresh_conn, "/dashboard")

      assert html =~ "fonts/opendyslexic.css"
      refute html =~ "fonts/inter-latin.css"
      assert html =~ ~s|--font-sans: "OpenDyslexic"|
    end

    test "Changing the font pushes a set_font event so the head updates without a refresh" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_font]")
      |> render_change(%{
        "_target" => ["ui", "font_family"],
        "ui" => %{"font_family" => "OpenDyslexic"}
      })

      # Without this push, the initial `<head>` (rendered once via root.html.heex) keeps
      # the old font across LV navigations until a full HTTP refresh.
      assert_push_event(view, "set_font", %{
        font_name: "OpenDyslexic",
        href: "/fonts/opendyslexic.css"
      })
    end

    test "As a user I want to select a different language" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)

      {:ok, refreshed_view, _html} = live(conn, "/dashboard")

      assert refreshed_view
             |> element("span[data-role=locale]")
             |> render() =~ "en"

      next = "/settings/user/preferences/appearance"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_language]")
      |> render_change(%{"Elixir.Bonfire.Common.Localise.Cldr" => %{"default_locale" => "fr"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, "/dashboard")

      assert refreshed_view
             |> element("span[data-role=locale]")
             |> render() =~ "fr"

      #  assert refreshed_view
      #  |> has_element?("span[data-role=locale]", "it")
    end

    # test "As a user I want to hide brand name" do
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/appearance"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_brand]")
    #   |> render_change(%{"Elixir.Bonfire.UI.Common.LogoLive" => %{"only_logo" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, next)
    #   # open_browser(refreshed_view)

    #   refute refreshed_view
    #          |> has_element?("div[data-id=logo] div[data-scope=logo_name]")
    # end

    # test "As a user I want to change avatar shape to square" do
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/appearance"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_avatar_shape]")
    #   |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"shape" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, "/@#{alice.character.username}")

    #   assert refreshed_view
    #          |> has_element?("div[data-scope=avatar]")

    #   assert refreshed_view
    #          |> has_element?("div[data-scope=avatar] div[data-square]")
    # end

    test "As a user I want to set the animal avatar" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      next = "/settings/user/preferences/behaviours"
      {:ok, view, _html} = live(conn, next)

      view
      |> element("form[data-scope=set_animal_avatar]")
      |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"animal_avatars" => "false"}})

      # force a refresh
      {:ok, refreshed_view, _html} = live(conn, next)

      refute refreshed_view
             |> has_element?("svg[data-scope=animal_avatar]")
    end
  end

  describe "Behaviours" do
    # test "As a user I want to hide avatar from the layout" do
    #   account = fake_account!()
    #   alice = fake_user!(account)
    #   conn = conn(user: alice, account: account)
    #   next = "/settings/user/preferences/behaviours"
    #   {:ok, view, _html} = live(conn, next)

    #   view
    #   |> element("form[data-scope=set_hide_avatar]")
    #   |> render_change(%{"Elixir.Bonfire.UI.Common.AvatarLive" => %{"hide_avatars" => "true"}})

    #   # force a refresh
    #   {:ok, refreshed_view, _html} = live(conn, next)

    #   refute refreshed_view
    #          |> has_element?("div[data-scope=sticky_menu] div[data-scope=avatar]")
    # end

    test "how many items to show in feeds and other lists" do
    end
  end

  describe "Wording of blocks" do
    alias Bonfire.Common.Vocabulary

    @user_behaviours "/settings/user/preferences/behaviours"
    @instance_behaviours "/settings/instance/preferences/behaviours"
    @trending_form "form[data-scope=set_wording_trending_tags]"
    @top_discussions_form "form[data-scope=set_wording_top_discussions]"
    # the fields for one's own words, shown once "Custom…" is chosen
    @trending_words_form "form[data-scope=set_wording_words_trending_tags]"

    # what the select posts: the setting's keys, as "Elixir.Module" => nested map
    defp choose_wording(kind, preset_id),
      do: %{"Elixir.Bonfire.Common.Vocabulary" => %{to_string(kind) => to_string(preset_id)}}

    # what the form for one's own words posts
    defp type_wording(kind, phrases),
      do: %{
        "Elixir.Bonfire.Common.Vocabulary" => %{
          "custom" => %{to_string(kind) => Map.new(phrases, fn {k, v} -> {to_string(k), v} end)}
        }
      }

    # the title a preset gives its block, whatever the extension that owns it ships
    defp title_of(kind, preset_id),
      do: Vocabulary.phrase(Vocabulary.preset_for(kind, preset_id), :title)

    # the Trending block's title as the viewer sees it, rendered directly rather than read from the dashboard, since not every flavour's dashboard has the block (jacobin leaves it out). The viewer is loaded as the session loads them, so their saved settings apply
    defp trending_titles(user, account) do
      current_user = Bonfire.Me.Users.get_current(id(user), id(account))

      render_component(&Bonfire.Tag.Web.WidgetTagsLive.render/1, %{
        widget_title: nil,
        wrapper_class: nil,
        always_show_reset_btn: false,
        __context__: %{current_user: current_user, current_account: account}
      })
      |> Floki.parse_fragment!()
      |> Floki.find("[data-role=widget-heading]")
      |> Enum.map(&(&1 |> Floki.text() |> String.trim()))
    end

    # an instance-level setting is also written to the app's config, which outlives the test and the rolled back database
    setup do
      originals =
        for kind <- Vocabulary.kinds(),
            key <- [[Vocabulary, kind], [Vocabulary, :custom, kind]],
            do: {key, Config.get(key)}

      on_exit(fn -> for {key, original} <- originals, do: Config.put(key, original) end)
    end

    test "As a user I can pick another wording for the Trending block", %{
      conn: conn,
      account: account,
      alice: alice
    } do
      [default, other | _] = Vocabulary.preset_ids(:trending_tags)

      {:ok, view, _html} = live(conn, @user_behaviours)

      assert has_element?(view, "#{@trending_form} option[value=#{other}]")

      view
      |> element(@trending_form)
      |> render_change(choose_wording(:trending_tags, other))

      titles = trending_titles(alice, account)

      assert title_of(:trending_tags, other) in titles
      refute title_of(:trending_tags, default) in titles
    end

    test "every block with several wordings has its own choice, listing all of them", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, @user_behaviours)

      assert :trending_tags in Vocabulary.kinds()
      assert :top_discussions in Vocabulary.kinds()

      for kind <- Vocabulary.kinds(), id <- Vocabulary.preset_ids(kind) ++ [:custom] do
        assert has_element?(view, "form[data-scope=set_wording_#{kind}] option[value=#{id}]"),
               "#{kind} offers #{id}"
      end
    end

    test "a block with a single wording can still be worded in one's own words", %{conn: conn} do
      Process.put(
        [:bonfire_common, Vocabulary, :kinds],
        solo: [module: Bonfire.UI.Me.RuntimeConfig, presets: %{solo: %{title: "Solo"}}]
      )

      {:ok, view, _html} = live(conn, @user_behaviours)

      assert has_element?(view, "form[data-scope=set_wording_solo] option[value=solo]")
      assert has_element?(view, "form[data-scope=set_wording_solo] option[value=custom]")
    end

    test "there are no fields for one's own words until Custom is chosen", %{conn: conn} do
      {:ok, view, _html} = live(conn, @user_behaviours)

      assert has_element?(view, @trending_form), "control: the choice is there"
      refute has_element?(view, @trending_words_form)

      view
      |> element(@trending_form)
      |> render_change(choose_wording(:trending_tags, :custom))

      # one field for each phrase of the block, whatever it has
      for key <- Vocabulary.phrase_keys(:trending_tags) do
        assert has_element?(view, "#{@trending_words_form} input[type=text][name*='[#{key}]']"),
               "a field for #{key}"
      end
    end

    test "As a user I can word the Trending block in my own words", %{
      conn: conn,
      account: account,
      alice: alice
    } do
      {:ok, view, _html} = live(conn, @user_behaviours)

      view
      |> element(@trending_form)
      |> render_change(choose_wording(:trending_tags, :custom))

      view
      |> element(@trending_words_form)
      |> render_submit(
        type_wording(:trending_tags, %{title: "What are the kids saying?", empty: ""})
      )

      titles = trending_titles(alice, account)

      assert "What are the kids saying?" in titles
      refute title_of(:trending_tags, :trending_tags) in titles
    end

    test "As an admin I word a block for the instance in my own words" do
      account = fake_account!()
      admin = fake_admin!(account)

      {:ok, view, _html} = live(conn(user: admin, account: account), @instance_behaviours)

      view
      |> element(@trending_form)
      |> render_change(choose_wording(:trending_tags, :custom))

      view
      |> element(@trending_words_form)
      |> render_submit(type_wording(:trending_tags, %{title: "What is the school yard saying?"}))

      bob = fake_user!(account)

      assert "What is the school yard saying?" in trending_titles(bob, account)
    end

    test "an instance's own wording for a block is one to choose", %{conn: conn} do
      Process.put(
        [:bonfire_common, Vocabulary, :custom_presets],
        top_discussions: %{
          school_yard: %{base: :top_discussions, title: "What do you hear in the school yard?"}
        }
      )

      {:ok, view, _html} = live(conn, @user_behaviours)

      assert has_element?(
               view,
               "#{@top_discussions_form} option",
               "What do you hear in the school yard?"
             )
    end

    test "As an admin I set the wording for the instance, and a user's own choice beats it" do
      [default, other | _] = Vocabulary.preset_ids(:trending_tags)

      account = fake_account!()
      admin = fake_admin!(account)

      {:ok, view, _html} = live(conn(user: admin, account: account), @instance_behaviours)

      view
      |> element(@trending_form)
      |> render_change(choose_wording(:trending_tags, other))

      bob = fake_user!(account)

      assert title_of(:trending_tags, other) in trending_titles(bob, account)

      carol = fake_user!(account)

      assert {:ok, %{__context__: %{current_user: carol}}} =
               Bonfire.Common.Settings.put([Vocabulary, :trending_tags], to_string(default),
                 current_user: carol,
                 scope: :user
               )

      carol_titles = trending_titles(carol, account)
      assert title_of(:trending_tags, default) in carol_titles
      refute title_of(:trending_tags, other) in carol_titles
    end
  end

  describe "Instance blocks scope switcher (#2018)" do
    test "the user/account/instance scope switcher is NOT shown on the instance blocks page" do
      account = fake_account!()
      admin = fake_admin!(account)
      conn = conn(user: admin, account: account)

      {:ok, view, _html} = live(conn, "/settings/instance/boundaries/blocked")

      # The persona switcher links to per-user/account settings that don't exist for
      # blocks (account-level blocks aren't a thing, and /settings/user/blocked has no
      # settings page → "No settings available"). So it must not be shown here. #2018
      refute view |> has_element?("a[href^='/settings/user/blocked']")
      refute view |> has_element?("a[href^='/settings/account/blocked']")
    end
  end

  describe "Instance extensions" do
    test "an admin can re-enable an extension that is disabled instance-wide" do
      account = fake_account!()
      admin = fake_admin!(account)

      {:ok, _} =
        Bonfire.Common.Settings.put([:ui, :enable_extensions_configuration], true,
          current_user: admin,
          scope: :user
        )

      Process.put([:bonfire_ui_groups, :modularity], :disabled)

      conn = conn(user: admin, account: account)

      # disconnected render, before the socket connects
      dead_html = conn |> get("/settings/instance/extensions") |> html_response(200)

      assert dead_html =~
               ~r/phx-value-extension="bonfire_ui_groups"[^>]*phx-value-scope="instance"|phx-value-scope="instance"[^>]*phx-value-extension="bonfire_ui_groups"/

      refute dead_html =~ "Contact the admins to enable this extension"

      {:ok, view, _html} = live(conn, "/settings/instance/extensions")

      assert view
             |> has_element?(
               "input[phx-value-extension=bonfire_ui_groups][phx-value-scope=instance]"
             )

      refute render(view) =~ "Contact the admins to enable this extension"
    end
  end

  # The instance's banner and description are `:edit` on the instance, which admins and instance moderators hold, not every local user (who holds `:contribute` there through `instance_care`, once `can?(_, _, :instance)` stopped failing for everyone but admins)
  describe "Instance configuration" do
    test "an ordinary local user doesn't get the instance banner upload", %{account: account} do
      user = fake_user!(account)

      conn(user: user, account: account)
      |> visit("/settings/instance/configuration")
      |> refute_has("[data-id=upload_banner]")
    end

    test "an instance moderator does", %{account: account} do
      moderator = Bonfire.Me.Fake.instance_moderator!(fake_user!(account))

      conn(user: moderator, account: account)
      |> visit("/settings/instance/configuration")
      |> assert_has("[data-id=upload_banner]")
    end

    test "an admin does", %{account: account} do
      admin = fake_admin!(account)

      conn(user: admin, account: account)
      |> visit("/settings/instance/configuration")
      |> assert_has("[data-id=upload_banner]")
    end

    # the mailer reads only the MAIL_* env vars, so a form saving mail settings would change nothing
    test "an admin doesn't get the email configuration, which only env vars set", %{
      account: account
    } do
      admin = fake_admin!(account)

      conn(user: admin, account: account)
      |> visit("/settings/instance/configuration")
      |> assert_has("[data-id=upload_banner]")
      |> refute_has("input[name*=mail_key]")
      |> refute_has("*", text: "Email Configuration")
    end
  end

  # what the instance asks of servers fetching from it: not at all, all but public profiles (which is what having it on meant before it was a choice, stored as `true`), or everything
  describe "Require authentication from federated servers" do
    setup %{account: account} do
      previous = Application.get_env(:activity_pub, :reject_unsigned)

      on_exit(fn ->
        if is_nil(previous),
          do: Application.delete_env(:activity_pub, :reject_unsigned),
          else: Application.put_env(:activity_pub, :reject_unsigned, previous)
      end)

      {:ok, conn: conn(user: fake_admin!(account), account: account)}
    end

    test "an instance that had it switched on shows it as required except for public profiles",
         %{conn: conn} do
      Application.put_env(:activity_pub, :reject_unsigned, true)

      conn
      |> visit("/settings/instance/configuration")
      |> wait_async()
      |> assert_has("#reject_unsigned option", text: "Not required")
      |> assert_has("#reject_unsigned option", text: "Required for everything")
      |> assert_has("#reject_unsigned option[selected]",
        text: "Required, except for public profiles"
      )
    end

    test "an admin can require it for everything, or for all but public profiles", %{conn: conn} do
      Application.put_env(:activity_pub, :reject_unsigned, false)

      session =
        conn
        |> visit("/settings/instance/configuration")
        |> wait_async()
        |> select("Require authentication from federated servers",
          option: "Required for everything"
        )

      assert ActivityPub.Config.signed_fetch_required() == :all

      select(session, "Require authentication from federated servers",
        option: "Required, except for public profiles"
      )

      assert ActivityPub.Config.signed_fetch_required() == :except_public_actors
    end
  end

  describe "Instance icon" do
    test "uses the high-resolution instance icon uploader", %{account: account} do
      original_icon = Config.get([:ui, :theme, :instance_icon])

      on_exit(fn ->
        Config.put([:ui, :theme, :instance_icon], original_icon)
      end)

      admin = fake_admin!(account)
      conn = conn(user: admin, account: account)
      {:ok, view, _html} = live(conn, "/settings/instance/configuration")

      file =
        Path.expand(
          "../../../bonfire_files/test/fixtures/600x800.png",
          __DIR__
        )

      icon =
        file_input(view, "[data-id=upload_icon]", :icon, [
          %{
            last_modified: 1_594_171_879_000,
            name: "instance-icon.png",
            content: File.read!(file),
            type: "image/png"
          }
        ])

      html = render_upload(icon, "instance-icon.png")
      assert html =~ "/instance_icons/"

      icon_url =
        Bonfire.Common.Settings.get(
          [:bonfire, :ui, :theme, :instance_icon],
          nil,
          :instance
        )

      assert icon_url =~ "/instance_icons/"
    end
  end

  describe "Instance federation-mode selector (#2056)" do
    setup do
      # the saved mode lands in Application env, which the sandbox doesn't roll back: put back what was there, without the DB, since `on_exit` runs after the test's sandbox connection is gone
      instance_config = Application.get_env(:activity_pub, :instance)
      on_exit(fn -> Application.put_env(:activity_pub, :instance, instance_config) end)

      # this never reset anything: the `Settings.set` inside it queries the DB from a process the sandbox no longer allows, and the unawaited Task hides the failure
      # on_exit(fn ->
      #   parent = self()
      #
      #   Task.start(fn ->
      #     Ecto.Adapters.SQL.Sandbox.allow(Bonfire.Common.Repo, parent, self())
      #     Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, false)
      #   end)
      # end)

      account = fake_account!()
      admin = fake_admin!(account)
      conn = conn(user: admin, account: account)
      {:ok, conn: conn, admin: admin, account: account}
    end

    test "all four federation-mode cards are offered", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/settings/instance/configuration")

      for value <- ["true", "allowlist_only", "manual", "false"] do
        assert view
               |> has_element?("input[name='activity_pub[instance][federating]'][value=#{value}]"),
               "expected a federation-mode card with value=#{value}"
      end
    end

    # saved instance setting -> {radio card `value` pre-selected, computed federation_mode}
    @mode_cases [
      {true, "true", true},
      {:allowlist_only, "allowlist_only", :allowlist_only},
      {:manual, "manual", nil},
      {false, "false", false}
    ]

    for {stored, expected_value, expected_mode} <- @mode_cases do
      @stored stored
      @expected_value expected_value
      @expected_mode expected_mode

      test "highlights the #{inspect(@stored)} card and only that one (#2056)", %{conn: conn} do
        Bonfire.Common.Settings.set([activity_pub: [instance: [federating: @stored]]],
          scope: :instance,
          skip_boundary_check: true
        )

        {:ok, view, _html} = live(conn, "/settings/instance/configuration")

        assert view
               |> has_element?(
                 "input[name='activity_pub[instance][federating]'][value=#{@expected_value}][checked]"
               ),
               "expected the #{@expected_value} card to be checked"

        # none of the other cards may be checked
        for other <- ["true", "allowlist_only", "manual", "false"], other != @expected_value do
          refute view
                 |> has_element?(
                   "input[name='activity_pub[instance][federating]'][value=#{other}][checked]"
                 ),
                 "did not expect the #{other} card to be checked"
        end
      end

      test "clicking the #{inspect(@stored)} card persists it (and stays highlighted on reload)",
           %{conn: conn} do
        # start from a different mode so the change is meaningful
        Bonfire.Common.Settings.set([activity_pub: [instance: [federating: true]]],
          scope: :instance,
          skip_boundary_check: true
        )

        {:ok, view, _html} = live(conn, "/settings/instance/configuration")

        # selecting a card fires the form's phx-change → Settings:set
        view
        |> element("form[data-scope=set_federation]")
        |> render_change(%{
          "scope" => "instance",
          "activity_pub" => %{"instance" => %{"federating" => @expected_value}}
        })

        # the change must actually persist as the computed instance federation_mode
        assert Bonfire.Federate.ActivityPub.federation_mode() == @expected_mode,
               "expected federation_mode() to be #{inspect(@expected_mode)} after saving"

        # ...and a fresh mount must reflect the saved choice
        {:ok, reloaded, _html} = live(conn, "/settings/instance/configuration")

        assert reloaded
               |> has_element?(
                 "input[name='activity_pub[instance][federating]'][value=#{@expected_value}][checked]"
               ),
               "expected the #{@expected_value} card to remain checked after saving"
      end
    end

    test "a mode saved by an earlier test doesn't outlive it" do
      assert Bonfire.Federate.ActivityPub.federation_mode() == true,
             "the instance mode is kept in Application env, which the sandbox doesn't roll back, so whatever a test here saved must be undone when it ends or every test after it runs with federation off"
    end
  end

  describe "User federation-mode selector (#2056, shared component)" do
    setup do
      # Instance federation settings persist in Application env / DB and are NOT rolled back by the
      # Ecto sandbox, so earlier tests in this describe (e.g. "instance manual"/"instance allowlist")
      # leak their restrictive instance mode into later tests — clamping/hiding the `true` and
      # `allowlist_only` user cards. Reset to the open default before each test so the highlight
      # tests see all four cards reflect the user's own saved choice. See bonfire-app#2056.
      Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, false)
      instance_config = Application.get_env(:activity_pub, :instance)
      Bonfire.Federate.ActivityPub.set_federating(:instance, true)

      # the saved mode lands in Application env, which the sandbox doesn't roll back: put back what was there, without the DB, since `on_exit` runs after the test's sandbox connection is gone
      on_exit(fn -> Application.put_env(:activity_pub, :instance, instance_config) end)

      # this never reset anything: the `Settings.set` inside it queries the DB from a process the sandbox no longer allows, and the unawaited Task hides the failure
      # on_exit(fn ->
      #   parent = self()
      #
      #   Task.start(fn ->
      #     Ecto.Adapters.SQL.Sandbox.allow(Bonfire.Common.Repo, parent, self())
      #     Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, false)
      #   end)
      # end)

      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      {:ok, conn: conn, alice: alice, account: account}
    end

    # --- option visibility, constrained by the instance's own mode ---

    test "instance open → all four user options are offered", %{conn: conn} do
      Bonfire.Federate.ActivityPub.set_federating(:instance, true)

      {:ok, view, _html} = live(conn, "/settings/user/safety")

      for value <- ["true", "allowlist_only", "manual", "false"] do
        assert view
               |> has_element?("input[name='activity_pub[user_federating]'][value=#{value}]"),
               "expected the #{value} option to be offered"
      end
    end

    test "instance allowlist-only → the Open option is hidden", %{conn: conn} do
      Bonfire.Federate.ActivityPub.set_allowlist_only(:instance, true)

      {:ok, view, _html} = live(conn, "/settings/user/safety")

      refute view |> has_element?("input[name='activity_pub[user_federating]'][value=true]")

      assert view
             |> has_element?("input[name='activity_pub[user_federating]'][value=allowlist_only]")

      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=manual]")
      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=false]")
    end

    test "instance manual → only manual and disabled are offered", %{conn: conn} do
      Bonfire.Common.Settings.set([activity_pub: [instance: [federating: :manual]]],
        scope: :instance,
        skip_boundary_check: true
      )

      {:ok, view, _html} = live(conn, "/settings/user/safety")

      refute view |> has_element?("input[name='activity_pub[user_federating]'][value=true]")

      refute view
             |> has_element?("input[name='activity_pub[user_federating]'][value=allowlist_only]")

      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=manual]")
      assert view |> has_element?("input[name='activity_pub[user_federating]'][value=false]")
    end

    # --- highlight reflects the user's saved (effective) choice ---

    for {stored, expected_value} <- [
          {true, "true"},
          {:allowlist_only, "allowlist_only"},
          {:manual, "manual"},
          {false, "false"}
        ] do
      @stored stored
      @expected_value expected_value

      test "saved user mode #{inspect(@stored)} highlights the #{@expected_value} card",
           %{conn: conn, alice: alice} do
        Bonfire.Common.Settings.put([:activity_pub, :user_federating], @stored,
          current_user: alice
        )

        {:ok, view, _html} = live(conn, "/settings/user/safety")

        assert view
               |> has_element?(
                 "input[name='activity_pub[user_federating]'][value=#{@expected_value}][checked]"
               ),
               "expected the #{@expected_value} card to be checked"
      end
    end
  end

  describe "Privacy & Settings" do
    test "default boundary" do
      account = fake_account!()
      alice = fake_user!(account)
      conn = conn(user: alice, account: account)
      {:ok, view, _html} = live(conn, "/settings/user/bonfire_ui_boundaries")

      # The picker is a select-style dropdown: the currently-selected audience
      # is shown in the dropdown trigger (not as a highlighted grid tile).
      # Default is "public", so the trigger should read "Public".
      assert view
             |> has_element?(
               "[data-scope=safety_boundary_default] #boundaries_general_access_list_trigger",
               "Public"
             )

      # ...and the selected option in the panel carries a check marker.
      assert view
             |> has_element?(
               "[data-scope=safety_boundary_default] button[data-scope=public_boundary] [iconify='ph:check-bold']"
             )

      refute view
             |> has_element?(
               "[data-scope=safety_boundary_default] button[data-scope=local_boundary] [iconify='ph:check-bold']"
             )

      # The options live in the (DOM-rendered) dropdown panel; pick "Local".
      view
      |> element("[data-scope=safety_boundary_default] button[data-scope=local_boundary]")
      |> render_click()

      # open_browser(view)
      {:ok, refreshed_view, _html} = live(conn, "/settings/user/bonfire_ui_boundaries")

      # After selecting, the trigger reflects the new default audience...
      assert refreshed_view
             |> has_element?(
               "[data-scope=safety_boundary_default] #boundaries_general_access_list_trigger",
               "Local"
             )

      # ...and the check marker moves to the newly-selected option.
      assert refreshed_view
             |> has_element?(
               "[data-scope=safety_boundary_default] button[data-scope=local_boundary] [iconify='ph:check-bold']"
             )
    end
  end

  describe "Safety - hide notifications and messages from" do
    # the same switches as notification preferences and the messages list, in place of the old "Who can reach me by direct message" select
    test "shows a switch per audience, and not the old direct message select", %{conn: conn} do
      conn
      |> visit("/settings/user/safety")
      |> assert_has("#notification-audiences", text: "Hide notifications and messages from")
      |> assert_has("#notification-audience-not_followed")
      |> refute_has("[data-scope=set_dm_privacy]")
    end
  end

  describe "Safety - keyword filter (SettingsListLive)" do
    # the ported keyword filter reads/writes this setting as a list of strings
    @keyword_keys [:activity_pub, :mrf_keyword, :reject]
    @warn_keys [:activity_pub, :mrf_keyword, :warn]
    @safety_path "/settings/user/safety"

    test "adding a keyword shows it as a chip and persists across a reload", %{conn: conn} do
      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_reject", fn session ->
        session
        |> fill_in("Hide completely", with: "spammy")
        |> click_button("Add")
      end)
      |> assert_has("#filter_keywords", text: "spammy")

      # a fresh visit reads it back through the component's real Settings path, proving it persisted
      # (not just the in-memory assign)
      conn
      |> visit(@safety_path)
      |> assert_has("#filter_keywords", text: "spammy")
    end

    test "a bulk paste splits comma/newline-separated keywords into separate chips", %{conn: conn} do
      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_reject", fn session ->
        session
        |> fill_in("Hide completely", with: "alpha, beta\ngamma")
        |> click_button("Add")
      end)
      |> assert_has("#filter_keywords li", text: "alpha")
      |> assert_has("#filter_keywords li", text: "beta")
      |> assert_has("#filter_keywords li", text: "gamma")
    end

    test "removing a keyword drops the chip and stops persisting it", %{conn: conn, alice: alice} do
      {:ok, _} =
        Bonfire.Common.Settings.put(@keyword_keys, ["removeme"],
          current_user: alice,
          scope: :user
        )

      conn
      |> visit(@safety_path)
      |> assert_has("#filter_keywords", text: "removeme")
      |> within("#filter_keywords_reject", fn session ->
        click_button(session, "Remove: removeme")
      end)
      |> refute_has("#filter_keywords li", text: "removeme")

      # the removal persists: a fresh visit no longer shows it
      conn
      |> visit(@safety_path)
      |> refute_has("#filter_keywords li", text: "removeme")
    end

    test "keywords are kept as typed, so a number or a capitalised word still hides posts", %{
      conn: conn,
      alice: alice
    } do
      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_reject", fn session ->
        session
        |> fill_in("Hide completely", with: "2026, Enum")
        |> click_button("Add")
      end)

      conn
      |> visit(@safety_path)
      |> assert_has("#filter_keywords li", text: "2026")
      |> assert_has("#filter_keywords li", text: "Enum")

      # stored as typed: not the number 2026 and the module `Enum`
      alice = Bonfire.Common.Repo.preload(alice, :settings, force: true)
      assert get_in(alice.settings.json, @keyword_keys) == ["2026", "Enum"]

      author = fake_user!()

      {:ok, _} =
        Bonfire.Posts.publish(
          current_user: author,
          post_attrs: %{post_content: %{html_body: "the 2026 recap"}},
          boundary: "public"
        )

      alice = Bonfire.Common.Repo.preload(alice, :settings, force: true)

      refute :explore
             |> Bonfire.Social.FeedLoader.feed_postloaded(limit: 20, current_user: alice)
             |> Bonfire.Social.FeedLoader.feed_contains?("the 2026 recap", postload: false)
    end

    test "a person's keywords don't include the instance's", %{conn: conn} do
      # an instance save also puts the list into the app config, which every later test reads: put back exactly what was there (the stored row goes with the test's transaction)
      previous_config = Application.get_env(:activity_pub, :mrf_keyword)

      on_exit(fn ->
        if previous_config,
          do: Application.put_env(:activity_pub, :mrf_keyword, previous_config),
          else: Application.delete_env(:activity_pub, :mrf_keyword)
      end)

      {:ok, _} =
        Bonfire.Common.Settings.put_raw(@keyword_keys, ["instancewide"],
          scope: :instance,
          skip_boundary_check: true
        )

      conn
      |> visit(@safety_path)
      |> refute_has("#filter_keywords li", text: "instancewide")
    end

    test "a person's list says what it hides and how * works", %{conn: conn} do
      conn
      |> visit(@safety_path)
      |> assert_has("#filter_keywords", text: "Hide posts with these words.")
      |> assert_has("#filter_keywords", text: "spam* hides spammer and spamming")
      |> assert_has("#filter_keywords", text: "*spam* also hides antispam and antispammer")
      |> assert_has("#filter_keywords", text: "so cool also catches C00L")
      |> refute_has("#filter_keywords", text: "Posts from other instances with these words")
    end

    test "the instance's list says what happens to posts from other instances and to local ones",
         %{account: account} do
      conn(user: fake_admin!(account), account: account)
      |> visit("/settings/instance/safety")
      |> assert_has("#filter_keywords",
        text: "Posts from other instances with these words are rejected."
      )
      |> assert_has("#filter_keywords",
        text: "Local posts with them are hidden from everyone except the author."
      )
      |> refute_has("#filter_keywords", text: "Hide posts with these words.")
    end

    test "a second list hides behind a warning, kept as typed, at each scope", %{
      conn: conn,
      alice: alice,
      account: account
    } do
      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_warn", fn session ->
        session
        |> fill_in("Hide behind a warning", with: "2026, spoilers")
        |> click_button("Add")
      end)

      conn
      |> visit(@safety_path)
      |> assert_has("#filter_keywords_warn li", text: "spoilers")
      |> refute_has("#filter_keywords_reject li", text: "spoilers")
      |> assert_has("#filter_keywords_warn", text: "behind a warning")

      alice = Bonfire.Common.Repo.preload(alice, :settings, force: true)
      assert get_in(alice.settings.json, @warn_keys) == ["2026", "spoilers"]

      # the instance's: an instance save also puts the lists into the app config, which every later test reads
      previous_config = Application.get_env(:activity_pub, :mrf_keyword)

      on_exit(fn ->
        if previous_config,
          do: Application.put_env(:activity_pub, :mrf_keyword, previous_config),
          else: Application.delete_env(:activity_pub, :mrf_keyword)
      end)

      admin_conn = conn(user: fake_admin!(account), account: account)

      admin_conn
      |> visit("/settings/instance/safety")
      |> within("#filter_keywords_warn", fn session ->
        session
        |> fill_in("Hide behind a warning", with: "instancewarn")
        |> click_button("Add")
      end)

      admin_conn
      |> visit("/settings/instance/safety")
      |> assert_has("#filter_keywords_warn li", text: "instancewarn")
      |> assert_has("#filter_keywords_warn", text: "behind a warning")
    end

    test "a keyword moves from one list to the other, and back", %{conn: conn, alice: alice} do
      {:ok, _} =
        Bonfire.Boundaries.BlockKeywords.put_block_keywords_settings(["alpha", "beta"],
          current_user: alice
        )

      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_reject", fn session ->
        click_button(session, "Move alpha to Hide behind a warning")
      end)
      |> assert_has("#filter_keywords_warn li", text: "alpha")
      |> refute_has("#filter_keywords_reject li", text: "alpha")

      conn
      |> visit(@safety_path)
      |> assert_has("#filter_keywords_warn li", text: "alpha")
      |> refute_has("#filter_keywords_reject li", text: "alpha")
      |> assert_has("#filter_keywords_reject li", text: "beta")

      alice = Bonfire.Common.Repo.preload(alice, :settings, force: true)
      assert get_in(alice.settings.json, @keyword_keys) == ["beta"]
      assert get_in(alice.settings.json, @warn_keys) == ["alpha"]

      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_warn", fn session ->
        click_button(session, "Move alpha to Hide completely")
      end)
      |> assert_has("#filter_keywords_reject li", text: "alpha")
      |> refute_has("#filter_keywords_warn li", text: "alpha")

      alice = Bonfire.Common.Repo.preload(alice, :settings, force: true)
      assert get_in(alice.settings.json, @keyword_keys) == ["beta", "alpha"]
      assert get_in(alice.settings.json, @warn_keys) == []
    end

    test "adding a keyword that is in the other list moves it, so it is never in both", %{
      conn: conn,
      alice: alice
    } do
      {:ok, _} =
        Bonfire.Boundaries.BlockKeywords.put_block_keywords_settings(["alpha"],
          current_user: alice
        )

      conn
      |> visit(@safety_path)
      |> within("#filter_keywords_warn", fn session ->
        session
        |> fill_in("Hide behind a warning", with: "alpha")
        |> click_button("Add")
      end)
      |> assert_has("#filter_keywords_warn li", text: "alpha")
      |> refute_has("#filter_keywords_reject li", text: "alpha")

      alice = Bonfire.Common.Repo.preload(alice, :settings, force: true)
      assert get_in(alice.settings.json, @keyword_keys) == []
      assert get_in(alice.settings.json, @warn_keys) == ["alpha"]
    end
  end

  describe "Instance signup email-domain allowlist" do
    @instance_config_path "/settings/instance/configuration"
    @domains_keys [Bonfire.Me.Accounts, :allowed_email_domains]
    @passwordless_locked_text "Always on while signups are limited to certain email domains or sign-in services"

    setup %{account: account} do
      orig = Config.get(@domains_keys)
      on_exit(fn -> Config.put(@domains_keys, orig) end)
      %{conn: conn(user: fake_admin!(account), account: account)}
    end

    test "an admin adds a domain: it normalizes, persists, and turns the gate on", %{conn: conn} do
      refute Bonfire.Me.Accounts.signup_domain_gate_active?()

      conn
      |> visit(@instance_config_path)
      |> within("#allowed_email_domains", fn session ->
        session
        |> fill_in("Restrict signups to email domains", with: "MyOrg.com")
        |> click_button("Add")
      end)
      |> assert_has("#allowed_email_domains", text: "myorg.com")

      assert Bonfire.Me.Accounts.signup_domain_gate_active?()
      assert Bonfire.Me.Accounts.email_on_allowed_domain?("someone@myorg.com")

      # persists across a reload
      conn
      |> visit(@instance_config_path)
      |> assert_has("#allowed_email_domains", text: "myorg.com")
    end

    test "removing the last domain turns the gate back off", %{conn: conn} do
      conn
      |> visit(@instance_config_path)
      |> within("#allowed_email_domains", fn session ->
        session
        |> fill_in("Restrict signups to email domains", with: "myorg.com")
        |> click_button("Add")
      end)
      |> assert_has("#allowed_email_domains", text: "myorg.com")
      |> within("#allowed_email_domains", fn session ->
        click_button(session, "Remove: myorg.com")
      end)
      |> refute_has("#allowed_email_domains li", text: "myorg.com")

      refute Bonfire.Me.Accounts.signup_domain_gate_active?()
    end

    test "checking a sign-in service trusts it for new accounts", %{conn: conn} do
      trusted_keys = [Bonfire.Me.Accounts, :trusted_signup_providers]
      orig = Config.get(trusted_keys)
      on_exit(fn -> Config.put(trusted_keys, orig) end)

      # a configured OAuth provider, so the page lists it
      Process.put([:bonfire_open_id, :oauth2_providers],
        github: [display_name: "GitHub", redirect_uri: "/openid/client/github"]
      )

      refute "github" in Bonfire.Me.Accounts.trusted_signup_providers()

      conn
      |> visit(@instance_config_path)
      |> check("GitHub")

      assert "github" in Bonfire.Me.Accounts.trusted_signup_providers()
    end

    test "while a domain is set, a fresh load shows passwordless as required (not editable)", %{
      conn: conn
    } do
      Bonfire.Common.Settings.put(@domains_keys, ["myorg.com"],
        scope: :instance,
        skip_boundary_check: true
      )

      conn
      |> visit(@instance_config_path)
      |> assert_has("div", text: @passwordless_locked_text)
    end

    test "while only a sign-in service is trusted, a fresh load shows passwordless as required (not editable)",
         %{conn: conn} do
      Process.put([:bonfire_me, Bonfire.Me.Accounts, :trusted_signup_providers], [:github])
      refute Bonfire.Me.Accounts.signup_domain_gate_active?()

      conn
      |> visit(@instance_config_path)
      |> assert_has("div", text: @passwordless_locked_text)
    end
  end
end
