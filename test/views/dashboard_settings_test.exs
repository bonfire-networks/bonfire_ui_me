defmodule Bonfire.UI.Me.DashboardSettingsTest do
  @moduledoc "Dashboard settings: the dashboard's edit mode, always on, and what's changed there is what the dashboard renders."
  use Bonfire.UI.Me.ConnCase, async: false

  @settings "/settings/user/dashboard"
  @main_area "[data-role=widget_area][data-area=main]"
  @sidebar_area "[data-role=widget_area][data-area=sidebar]"

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  # every widget the dashboard's main area offers, in order, as `%{key, name, widget}`
  defp options(me),
    do:
      Enum.map(
        Bonfire.UI.Common.Widgets.offered({Bonfire.Web.Views.DashboardLive, :main}, me),
        &%{key: &1.id, name: &1.name, widget: &1, included: &1.included}
      )

  # the ones the dashboard shows
  defp shown(me), do: Enum.filter(options(me), & &1.included)

  # a custom feed preset of the user's, hidden from the feed tabs; returns its name and the user the put returns, as settings are preloaded on it and a later put on the old user would drop the preset
  defp put_hidden_preset(me, slug) do
    name = Faker.Lorem.sentence()

    assert {:ok, %{__context__: %{current_user: me}}} =
             Bonfire.Common.Settings.put(
               [:bonfire_social, Bonfire.Social.Feeds, :feed_presets, slug],
               %{
                 name: name,
                 icon: "ph:rss-simple-fill",
                 exclude_from_nav: true,
                 filters: %{feed_name: :local}
               },
               current_user: me
             )

    {name, me}
  end

  # positions of the main-area widgets as the dashboard renders them
  defp dashboard_order(conn) do
    {:ok, _view, html} = live(conn, "/dashboard")

    html
    |> Floki.parse_document!()
    |> Floki.find("#dashboard_main_widgets [data-item]")
    |> Enum.flat_map(&Floki.attribute(&1, "data-item"))
  end

  # the ids of the tiles in an area of the settings page, in order
  defp tile_ids(view, area_selector) do
    view
    |> render()
    |> Floki.parse_document!()
    |> Floki.find("#{area_selector} [data-widget-id]")
    |> Enum.flat_map(&Floki.attribute(&1, "data-widget-id"))
  end

  # an area's draggable list on the settings page: its `data-parent` and the `data-item` of each tile, as the Draggable hook reads them
  defp list(view, area_selector) do
    [list] =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("#{area_selector} ul[phx-hook=Draggable]")

    [parent] = Floki.attribute(list, "data-parent")
    [event] = Floki.attribute(list, "data-event")

    items =
      list
      |> Floki.find("[data-widget-id]")
      |> Map.new(fn li ->
        {hd(Floki.attribute(li, "data-widget-id")), hd(Floki.attribute(li, "data-item"))}
      end)

    %{parent: parent, event: event, items: items}
  end

  # what the Draggable hook sends on a drop (LiveViewTest runs no JS)
  defp drop(view, area_selector, source_id, to_area_selector, target_ids) do
    from = list(view, area_selector)
    to = if to_area_selector == area_selector, do: from, else: list(view, to_area_selector)
    items = Map.merge(to.items, from.items)

    view
    |> element("#{area_selector} ul[phx-hook=Draggable]")
    |> render_hook(from.event, %{
      "old_index" => 0,
      "new_index" => Enum.find_index(target_ids, &(&1 == source_id)),
      "parent_item" => from.parent,
      "source_item" => items[source_id],
      "target_parent" => to.parent,
      "target_order" => Enum.map(target_ids, &items[&1])
    })
  end

  defp remove(view, id),
    do: view |> element("[data-role=remove_widget][phx-value-id=#{id}]") |> render_click()

  # the sheet's cards render once it's open
  defp open_add(view, area),
    do:
      view
      |> element("[data-role=add_widgets][data-area=#{area}] [data-role=open_modal]")
      |> render_click()

  defp add(view, id, area),
    do:
      view
      |> element("[data-role=add_widget][phx-value-id=#{id}][phx-value-area=#{area}]")
      |> render_click()

  test "settings has a Dashboard page, above Feeds", %{conn: conn} do
    {:ok, _view, html} = live(conn, @settings)

    nav =
      Floki.parse_document!(html)
      |> Floki.find("a[href]")
      |> Enum.flat_map(&Floki.attribute(&1, "href"))

    dashboard_at = Enum.find_index(nav, &(&1 == @settings))
    feeds_at = Enum.find_index(nav, &(&1 == "/settings/user/feeds"))

    assert dashboard_at, "the settings nav links to the dashboard page"
    assert dashboard_at < feeds_at
  end

  # case 1
  test "shows both areas as edit mode tiles, already editing, with no Customize or Done", %{
    conn: conn,
    me: me
  } do
    Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
      main: [:suggested_profiles, :instance_pinned],
      sidebar: [:community_rules, :mods]
    )

    {:ok, view, _html} = live(conn, @settings)

    assert has_element?(view, "[data-role=widget_areas][data-widgets-editing]")
    assert tile_ids(view, @main_area) == Enum.map(shown(me), &to_string(&1.key))
    assert tile_ids(view, @sidebar_area) == ["community_rules", "mods"]

    # each tile is the widget's name and controls, never its content
    assert has_element?(
             view,
             "#{@sidebar_area} [data-widget-id=mods] [data-role=widget-edit-controls]",
             "Moderators"
           )

    refute has_element?(view, "[data-role=widget_areas] aside")

    refute has_element?(view, "[data-role=customize_widgets]")
    assert has_element?(view, "[data-role=widgets_edit_bar]", "Drag to rearrange")

    # custom widgets are the instance's to write
    open_add(view, "main")
    refute has_element?(view, "[data-role=custom_widget]")
    refute has_element?(view, "[data-role=widgets_edit_done]")
  end

  # case 2
  test "removing a tile takes the widget off that member's dashboard, and Undo puts it back", %{
    conn: conn,
    me: me
  } do
    %{key: key, widget: widget} = List.last(shown(me))
    module = to_string(widget.module)
    assert module in dashboard_order(conn)

    {:ok, view, _html} = live(conn, @settings)
    remove(view, key)

    refute has_element?(view, "#{@main_area} [data-widget-id=#{key}]")
    refute module in dashboard_order(conn)

    view |> element("[data-role=undo_remove_widget]") |> render_click()

    assert has_element?(view, "#{@main_area} [data-widget-id=#{key}]")
    assert module in dashboard_order(conn)
  end

  describe "the sidebar" do
    @sidebar_keys [:bonfire, Bonfire.Web.Views.DashboardLive, :widgets]

    # the ids of the widgets in an area of the dashboard, in the order it renders them
    defp area_widget_ids(conn, area_selector) do
      {:ok, _view, html} = live(conn, "/dashboard")

      html
      |> Floki.parse_document!()
      |> Floki.find("#{area_selector} [data-widget-id]")
      |> Enum.flat_map(&Floki.attribute(&1, "data-widget-id"))
    end

    test "shows the flavour's sidebar widgets, in its order", %{conn: conn} do
      Process.put(@sidebar_keys, sidebar: [:community_rules, :mods])

      assert ["community_rules", "mods"] ==
               area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")
    end

    test "a member removes a sidebar widget, and only their sidebar loses it", %{conn: conn} do
      Process.put(@sidebar_keys, sidebar: [:community_rules, :mods])

      other_account = fake_account!()
      other_conn = conn(user: fake_user!(other_account), account: other_account)

      assert "mods" in area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")

      {:ok, view, _html} = live(conn, @settings)
      remove(view, "mods")

      sidebar = area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")
      refute "mods" in sidebar
      assert "community_rules" in sidebar

      assert "mods" in area_widget_ids(other_conn, "[data-id=secondary_sidebar_widgets]")
    end

    test "a member drags a sidebar widget to the main area", %{conn: conn} do
      Process.put(@sidebar_keys,
        main: [:suggested_profiles, :instance_pinned],
        sidebar: [:community_rules, :mods, :trending_links]
      )

      {:ok, view, _html} = live(conn, @settings)

      # the layout's right sidebar is hidden, and the two areas sit side by side
      refute has_element?(view, "[data-id=secondary_sidebar_widgets]")
      assert "community_rules" in tile_ids(view, @sidebar_area)

      drop(view, @sidebar_area, "community_rules", @main_area, [
        "suggested_profiles",
        "community_rules",
        "instance_pinned"
      ])

      assert tile_ids(view, @main_area) == [
               "suggested_profiles",
               "community_rules",
               "instance_pinned"
             ]

      refute "community_rules" in tile_ids(view, @sidebar_area)

      assert "community_rules" in area_widget_ids(conn, "#dashboard_main_widgets")
      refute "community_rules" in area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")
    end

    test "dragging a sidebar widget on the dashboard saves the order settings shows", %{
      conn: conn
    } do
      Process.put(@sidebar_keys, sidebar: [:community_rules, :mods])

      {:ok, view, html} = live(conn, "/dashboard")

      [list] =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-id=secondary_sidebar_widgets] ul[phx-hook=Draggable]")

      [parent] = Floki.attribute(list, "data-parent")
      [event] = Floki.attribute(list, "data-event")

      [rules, mods] =
        list |> Floki.find("[data-widget-id]") |> Enum.flat_map(&Floki.attribute(&1, "data-item"))

      view
      |> element("[data-id=secondary_sidebar_widgets] ul[phx-hook=Draggable]")
      |> render_hook(event, %{
        "old_index" => 1,
        "new_index" => 0,
        "parent_item" => parent,
        "source_item" => mods,
        "target_parent" => parent,
        "target_order" => [mods, rules]
      })

      assert ["mods", "community_rules"] ==
               area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")

      {:ok, settings, _html} = live(conn, @settings)
      assert ["mods", "community_rules"] == tile_ids(settings, @sidebar_area)
    end
  end

  # LiveViewTest runs no JS, so these check the markup the Draggable hook reads, and the event it sends
  describe "dragging tiles in settings" do
    @drag_keys [:bonfire, Bonfire.Web.Views.DashboardLive, :widgets]

    setup do
      Process.put(@drag_keys,
        main: [:suggested_profiles, :instance_pinned],
        sidebar: [:community_rules, :mods, :trending_links]
      )

      :ok
    end

    test "the two areas can be dragged, within and between them", %{conn: conn} do
      {:ok, view, _html} = live(conn, @settings)
      doc = view |> render() |> Floki.parse_document!()

      [main] = Floki.find(doc, "#{@main_area} ul[phx-hook=Draggable]")
      [sidebar] = Floki.find(doc, "#{@sidebar_area} ul[phx-hook=Draggable]")

      for list <- [main, sidebar] do
        assert Floki.attribute(list, "data-event") == ["Bonfire.UI.Common.Widgets:reorder"]
        assert [_ | _] = Floki.attribute(list, "data-sortable-group")
      end

      assert Floki.attribute(main, "data-sortable-group") ==
               Floki.attribute(sidebar, "data-sortable-group")

      assert Floki.attribute(main, "data-parent") == ["dashboard_main_widgets"]
      assert Floki.attribute(sidebar, "data-parent") == ["dashboard_sidebar_widgets"]

      for list <- [main, sidebar], tile <- Floki.find(list, "[data-widget-id]") do
        assert [_] = Floki.attribute(tile, "data-item")
        assert [_ | _] = Floki.find(tile, "[data-role=widget-drag-handle][data-sortable-handler]")
      end
    end

    test "dragging a tile within an area saves the order", %{conn: conn} do
      {:ok, view, _html} = live(conn, @settings)

      assert ["suggested_profiles", "instance_pinned"] = tile_ids(view, @main_area)

      drop(view, @main_area, "instance_pinned", @main_area, [
        "instance_pinned",
        "suggested_profiles"
      ])

      assert tile_ids(view, @main_area) == ["instance_pinned", "suggested_profiles"]

      assert dashboard_order(conn) == [
               "Elixir.Bonfire.UI.Reactions.PinnedCarouselLive",
               "Elixir.Bonfire.UI.Social.WidgetSuggestedProfilesLive"
             ]
    end

    test "dragging a tile to the sidebar moves it there, in the dropped position", %{conn: conn} do
      {:ok, view, _html} = live(conn, @settings)

      drop(view, @main_area, "suggested_profiles", @sidebar_area, [
        "community_rules",
        "suggested_profiles",
        "mods",
        "trending_links"
      ])

      refute "suggested_profiles" in tile_ids(view, @main_area)

      assert tile_ids(view, @sidebar_area) ==
               ["community_rules", "suggested_profiles", "mods", "trending_links"]

      sidebar_on_page = area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")
      assert Enum.find_index(sidebar_on_page, &(&1 == "suggested_profiles")) == 1
      refute "suggested_profiles" in area_widget_ids(conn, "#dashboard_main_widgets")
    end

    test "a drop the widget's width doesn't allow changes nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, @settings)

      main = tile_ids(view, @main_area)
      sidebar = tile_ids(view, @sidebar_area)

      # the Spotlight is only for the main area
      drop(view, @main_area, "instance_pinned", @sidebar_area, ["instance_pinned" | sidebar])

      assert_reply(view, %{refused: true})
      assert tile_ids(view, @main_area) == main
      assert tile_ids(view, @sidebar_area) == sidebar
      assert "Elixir.Bonfire.UI.Reactions.PinnedCarouselLive" in dashboard_order(conn)
    end
  end

  describe "the latest-activity feed" do
    defp dashboard_html(conn) do
      {:ok, _view, html} = live(conn, "/dashboard")
      html
    end

    defp has_feed?(html),
      do: Floki.find(Floki.parse_document!(html), "[data-id=feed]") != []

    defp position(html, selector) do
      # where an element starts in the page, to compare which comes first
      [{_, attrs, _} | _] = Floki.find(Floki.parse_document!(html), selector)
      {"id", id} = List.keyfind(attrs, "id", 0) || {"id", nil}
      :binary.match(html, ~s(id="#{id}")) |> elem(0)
    end

    test "is off unless chosen", %{conn: conn} do
      refute has_feed?(dashboard_html(conn))
    end

    test "is a widget like the others: offered in the main area's Add sheet, and added last", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, @settings)

      refute "feed" in tile_ids(view, @main_area)
      open_add(view, "main")
      assert has_element?(view, "[data-role=add_widget_card][data-widget-id=feed]", "Feed")

      add(view, "feed", "main")

      assert List.last(tile_ids(view, @main_area)) == "feed"

      html = dashboard_html(conn)
      assert has_feed?(html)
      assert position(html, "#dashboard_main_widgets") < position(html, "#feed-tabs")
      assert List.last(dashboard_order(conn)) == "Elixir.Bonfire.UI.Social.WidgetFeedLive"
    end

    test "with every widget hidden, the dashboard is just the feed", %{conn: conn, me: me} do
      for %{key: key} <- options(me) do
        Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, key], false,
          current_user: me
        )
      end

      Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, :feed], true,
        current_user: me
      )

      html = dashboard_html(conn)

      assert has_feed?(html)
      refute html =~ "You can customise your dashboard"
    end

    # case 6, the select that was its own form under the lists
    test "the Feed tile's dropdown offers every feed I may choose, and choosing one changes the dashboard's feed, not the default feed",
         %{conn: conn, me: me} do
      # a feed that no fallback would pick: it sorts after the built-in ones
      {name, me} = put_hidden_preset(me, :dashboard_custom)

      {:ok, _} =
        Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, :feed], true,
          current_user: me
        )

      tile_select = "#{@main_area} [data-widget-id=feed] [data-role=widget-edit-controls] select"

      conn
      |> visit(@settings)
      |> assert_has("#{tile_select} option[value=local]", text: "Local")
      |> assert_has("#{tile_select} option[value=dashboard_custom]", text: name)
      # by its selector, not within the tile: `within` hides the form the select belongs to
      |> PhoenixTest.select(tile_select, "Feed shown on the dashboard", option: name)
      |> visit("/settings/user/feeds")
      |> assert_has("#default-feed-select option[value=my][selected]")
      |> visit("/dashboard")
      |> assert_has("[data-id=feed] #feed-tab-dashboard_custom[aria-current=page]")
    end

    test "whoever chose the old feed-only mode keeps a feed", %{conn: conn, me: me} do
      Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :default_feed], :my,
        current_user: me
      )

      assert has_feed?(dashboard_html(conn))
    end
  end

  describe "the chosen feed and its tabs" do
    # feed on, Polls as the widget's feed; keep the user each put returns, as settings are preloaded on it
    setup %{me: me} do
      {:ok, %{__context__: %{current_user: me}}} =
        Bonfire.Common.Settings.put([Bonfire.UI.Social.WidgetFeedLive, :feed], :polls,
          current_user: me
        )

      {:ok, %{__context__: %{current_user: me}}} =
        Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, :feed], true,
          current_user: me
        )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__context__: %{current_user: me}, __changed__: %{}}
      }

      {:ok, me: me, socket: socket}
    end

    test "is the feed chosen for the widget", %{socket: socket} do
      feed = Bonfire.UI.Social.WidgetFeedLive.feed_props(socket)

      assert feed[:feed_name] == :polls
    end

    test "with no choice and :my as the default feed, it shows another feed" do
      # someone who never chose a widget feed, unlike the setup's user
      {:ok, %{__context__: %{current_user: other}}} =
        Bonfire.Common.Settings.put(
          [Bonfire.UI.Social.FeedLive, :default_feed],
          :my,
          current_user: fake_user!(fake_account!())
        )

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__context__: %{current_user: other}, __changed__: %{}}
      }

      feed = Bonfire.UI.Social.WidgetFeedLive.feed_props(socket)

      assert feed[:feed_name]
      refute feed[:feed_name] == :my
    end

    test "?feed=local shows the Local feed, headed by its title, with its tab active",
         %{conn: conn, socket: socket} do
      feed = Bonfire.UI.Social.WidgetFeedLive.feed_props(socket, "local")
      assert feed[:feed_name] == :local

      conn
      |> visit("/dashboard?feed=local")
      |> assert_has("#feed_heading", text: feed[:page_title])
      |> assert_has("[data-id=feed] #feed-tab-local[aria-current=page]")
    end

    test "an unknown ?feed falls back to the widget's feed", %{socket: socket} do
      feed = Bonfire.UI.Social.WidgetFeedLive.feed_props(socket, "nonsense")

      assert feed[:feed_name] == :polls
    end

    # on the dashboard, the tab that stays is the widget's feed's, not the default feed's (that one stays on `/feed`)
    test "the widget's feed's tab shows while another tab is open, even when it is hidden from the tabs",
         %{conn: conn, me: me} do
      {_name, me} = put_hidden_preset(me, :dashboard_default)

      assert {:ok, _} =
               Bonfire.Common.Settings.put(
                 [Bonfire.UI.Social.WidgetFeedLive, :feed],
                 :dashboard_default,
                 current_user: me
               )

      conn
      |> visit("/dashboard?feed=local")
      |> assert_has("[data-id=feed] #feed-tab-local[aria-current=page]")
      |> assert_has(
        "[data-id=feed] a#feed-tab-dashboard_default[href='/dashboard?feed=dashboard_default']"
      )
    end

    test "other hidden presets stay out of the tabs", %{conn: conn, me: me} do
      {_name, _me} = put_hidden_preset(me, :dashboard_hidden)

      conn
      |> visit("/dashboard")
      |> assert_has("[data-id=feed] #feed-tabs")
      |> refute_has("#feed-tab-dashboard_hidden")
    end

    test "tabs link to the dashboard, not to the feed pages", %{conn: conn} do
      conn
      |> visit("/dashboard")
      |> assert_has("[data-id=feed] a#feed-tab-local[href='/dashboard?feed=local']")
      |> refute_has("[data-id=feed] a[href^='/feed/']")
    end
  end

  describe "saved order" do
    test "a widget missing from the saved order goes after the placed ones, rather than tying with one",
         %{conn: conn, me: me} do
      [first, second, third | _] = options(me)

      # an order saved before `first` was offered, or while it was hidden
      {:ok, _} =
        Bonfire.Common.Settings.LiveHandler.save_widget_order(
          :dashboard_main_widgets,
          [third.widget.module, second.widget.module],
          current_user: me
        )

      assert [third_module, second_module | rest] = dashboard_order(conn)
      assert third_module == to_string(third.widget.module)
      assert second_module == to_string(second.widget.module)
      assert to_string(first.widget.module) in rest
    end

    test "settings lists them in the same order as the dashboard", %{conn: conn, me: me} do
      [first, second | _] = options(me)

      {:ok, _} =
        Bonfire.Common.Settings.LiveHandler.save_widget_order(
          :dashboard_main_widgets,
          Enum.map(
            [second, first | options(me) |> Enum.drop(2)],
            &Bonfire.UI.Common.WidgetsLive.order_key(&1.widget)
          ),
          current_user: me
        )

      {:ok, view, _html} = live(conn, @settings)

      settings_modules =
        view
        |> tile_ids(@main_area)
        |> Enum.map(fn key ->
          Enum.find(options(me), &(to_string(&1.key) == key)).widget
          |> Map.fetch!(:module)
          |> to_string()
        end)

      assert settings_modules == dashboard_order(conn)
    end
  end

  describe "spotlight" do
    setup do
      Bonfire.Social.Pins.list_spotlight_activities(cache: :reset)
      on_exit(fn -> Bonfire.Social.Pins.list_spotlight_activities(cache: :reset) end)
      :ok
    end

    test "is hidden when nothing is pinned", %{conn: conn} do
      conn
      |> visit("/dashboard")
      |> wait_async()
      |> refute_has("[data-role=widget-empty-state]", text: "Nothing in the spotlight yet")
      |> refute_has("#instance_pinned_widget aside")
    end

    test "shows a pinned post", %{conn: conn} do
      admin = fake_admin!(fake_account!())

      {:ok, post} =
        Bonfire.Posts.publish(
          current_user: admin,
          post_attrs: %{post_content: %{html_body: "a public post in the dashboard spotlight"}},
          boundary: "public"
        )

      Bonfire.Social.Pins.pin(admin, post, :instance)
      Bonfire.Social.Pins.list_spotlight_activities(cache: :reset)

      conn
      |> visit("/dashboard")
      |> wait_async()
      |> assert_has("[data-role=pinned_card]", text: "a public post in the dashboard spotlight")
    end
  end

  describe "widgets from the registry" do
    # Config.get reads these per test process
    @widgets_keys [:bonfire, Bonfire.Web.Views.DashboardLive, :widgets]
    @welcome_keys [:bonfire, :ui, :theme, :instance_welcome, :description]

    test "the dashboard shows the flavour's widgets, in the flavour's order", %{conn: conn} do
      Process.put(@widgets_keys, main: [:suggested_profiles, :instance_pinned])

      assert dashboard_order(conn) == [
               "Elixir.Bonfire.UI.Social.WidgetSuggestedProfilesLive",
               "Elixir.Bonfire.UI.Reactions.PinnedCarouselLive"
             ]
    end

    test "the instance's welcome text shows first when the flavour lists it", %{conn: conn} do
      Process.put(@widgets_keys, main: [:welcome, :suggested_profiles])
      Process.put(@welcome_keys, "Welcome to the **hall**")

      assert ["Elixir.Bonfire.UI.Common.WidgetWelcomeLive" | _] = dashboard_order(conn)

      conn
      |> visit("/dashboard")
      |> wait_async()
      |> assert_has("[data-id=widget_welcome] strong", text: "hall")
    end

    # facts show under the welcome text by default, and alone when there is no text
    test "with no welcome text, the welcome block shows only the instance's facts", %{conn: conn} do
      Process.put(@widgets_keys, main: [:welcome, :suggested_profiles])

      # an admin who empties the field saves "" (`nil` would fall back to the flavour's default text)
      Process.put(@welcome_keys, "")

      conn
      |> visit("/dashboard")
      |> wait_async()
      |> assert_has("[data-id=widget_welcome] [data-id=welcome_facts] #welcome-facts")
      |> refute_has("[data-id=widget_welcome] .prose")
    end
  end

  describe "instance defaults" do
    @instance_settings "/settings/instance/dashboard"
    @order_keys [:ui, :widget_order, :dashboard_main_widgets]

    # instance-scope settings are mirrored into the global Application env, which the sandbox doesn't roll back, so they're cleared before and after each test
    defp clear_instance_dashboard_settings(keys_list) do
      # `Config.delete/2` raises when a parent key has no value yet, so only clear what's there
      for keys <- keys_list,
          Bonfire.Common.Config.get(keys, nil) != nil do
        [otp_app | keys] = Bonfire.Common.Config.keys_tree(keys)
        Bonfire.Common.Config.delete(keys, otp_app)
      end
    end

    setup %{me: me} do
      account = fake_account!()
      admin = fake_admin!(account)

      clear = fn ->
        clear_instance_dashboard_settings([
          [Bonfire.Web.Views.DashboardLive, :include],
          [Bonfire.Web.Views.DashboardLive, :area],
          [Bonfire.Web.Views.HomeLive, :include],
          @order_keys,
          [:ui, :widget_order, :dashboard_sidebar_widgets]
        ])
      end

      clear.()
      on_exit(clear)

      {:ok, admin: admin, admin_conn: conn(user: admin, account: account), user: me}
    end

    test "the instance page is the user page, as tiles, with the feed in the Add sheet", %{
      admin_conn: admin_conn,
      user: user
    } do
      {:ok, view, _html} = live(admin_conn, @instance_settings)

      assert tile_ids(view, @main_area) == Enum.map(shown(user), &to_string(&1.key))
      open_add(view, "main")
      assert has_element?(view, "[data-role=add_widget_card][data-widget-id=feed]")

      # the Dashboard tab hides the layout's right sidebar, as its own area sits beside the main one
      refute has_element?(view, "[data-id=secondary_sidebar_widgets]")
    end

    test "removing a tile there hides the widget for everyone who hasn't chosen, but not in the admin's own settings",
         %{admin_conn: admin_conn, admin: admin, conn: conn, user: user} do
      %{key: key, widget: widget} = List.last(shown(user))

      assert to_string(widget.module) in dashboard_order(conn)

      {:ok, view, _html} = live(admin_conn, @instance_settings)
      remove(view, key)

      refute to_string(widget.module) in dashboard_order(conn)

      assert Bonfire.Common.Settings.get(
               [Bonfire.Web.Views.DashboardLive, :include, key],
               :unset,
               current_user: admin,
               one_scope_only: true
             ) == :unset,
             "the instance page must not write the admin's own settings"
    end

    test "a second change there is saved too, not reverted", %{
      admin_conn: admin_conn,
      conn: conn,
      user: user
    } do
      [first, second | _] = shown(user)

      {:ok, view, _html} = live(admin_conn, @instance_settings)
      remove(view, first.key)
      remove(view, second.key)

      order = dashboard_order(conn)
      refute to_string(first.widget.module) in order, "the first change was not kept"
      refute to_string(second.widget.module) in order, "the second change was not kept"

      {:ok, view, _html} = live(admin_conn, @instance_settings)
      refute to_string(first.key) in tile_ids(view, @main_area)
      refute to_string(second.key) in tile_ids(view, @main_area)
    end

    test "its tiles show the instance's widgets, not the admin's own", %{
      admin_conn: admin_conn,
      admin: admin,
      user: user
    } do
      %{key: key} = List.last(shown(user))

      {:ok, _} =
        Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, key], false,
          current_user: admin
        )

      {:ok, view, _html} = live(admin_conn, @instance_settings)

      assert to_string(key) in tile_ids(view, @main_area)
    end

    # case 3
    test "adding a widget from Add to sidebar there adds it for a member who hasn't chosen, but not to the admin's own dashboard",
         %{admin_conn: admin_conn, admin: admin, conn: conn} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles],
        sidebar: [:community_rules]
      )

      {:ok, view, _html} = live(admin_conn, @instance_settings)

      open_add(view, "sidebar")
      add(view, "mods", "sidebar")

      assert List.last(tile_ids(view, @sidebar_area)) == "mods"
      assert "mods" in area_widget_ids(conn, "[data-id=secondary_sidebar_widgets]")

      assert Bonfire.Common.Settings.get(
               [Bonfire.Web.Views.DashboardLive, :include, :mods],
               :unset,
               current_user: admin,
               one_scope_only: true
             ) == :unset,
             "the instance page must not write the admin's own settings"
    end

    # case 4
    test "dragging a tile there moves the widget for everyone who hasn't chosen, but a member's own order still wins",
         %{admin_conn: admin_conn, admin: admin, conn: conn, user: user} do
      [first, second | _] = shown(user)
      first_module = to_string(first.widget.module)
      second_module = to_string(second.widget.module)

      assert [^first_module, ^second_module | _] = dashboard_order(conn)

      {:ok, view, _html} = live(admin_conn, @instance_settings)
      [first_id, second_id | rest] = tile_ids(view, @main_area)
      drop(view, @main_area, second_id, @main_area, [second_id, first_id | rest])

      assert Bonfire.Common.Settings.get(@order_keys, %{}, :instance) != %{},
             "the move is saved as the instance's order"

      assert Bonfire.Common.Settings.get(@order_keys, %{},
               current_user: admin,
               one_scope_only: true
             ) == %{},
             "the instance page must not write the admin's own order"

      assert [^second_module, ^first_module | _] = dashboard_order(conn)

      # the member puts it back for themselves
      {:ok, own, _html} = live(conn, @settings)
      [own_first, own_second | own_rest] = tile_ids(own, @main_area)
      drop(own, @main_area, own_second, @main_area, [own_second, own_first | own_rest])

      assert [^first_module, ^second_module | _] = dashboard_order(conn)
    end

    # case 5
    test "someone who isn't an admin can't change the instance's widgets", %{
      conn: conn,
      user: user
    } do
      %{key: key} = List.last(shown(user))

      # the page only needs an account, so a member can open it and send the event
      {:ok, view, _html} = live(conn, @instance_settings)
      render_click(view, "Bonfire.UI.Common.Widgets:remove", %{"id" => to_string(key)})

      assert Bonfire.Common.Settings.get(
               [Bonfire.Web.Views.DashboardLive, :include, key],
               :unset,
               :instance
             ) == :unset

      # the handler itself, as the instance page sets it up: `Settings.put/3` refuses instance scope to a non-admin by raising (the page's event wrapper turns that into an error message)
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          __context__: %{current_user: user},
          __changed__: %{},
          flash: %{},
          widgets_place: Bonfire.Web.Views.DashboardLive,
          widgets_scope: :instance,
          widgets_for_guests: false
        }
      }

      assert_raise Bonfire.Fail, fn ->
        Bonfire.UI.Common.Widgets.LiveHandler.handle_event(
          "remove",
          %{"id" => to_string(key)},
          socket
        )
      end

      assert Bonfire.Common.Settings.get(
               [Bonfire.Web.Views.DashboardLive, :include, key],
               :unset,
               :instance
             ) == :unset
    end

    test "the instance settings nav links to it", %{admin_conn: admin_conn} do
      {:ok, view, _html} = live(admin_conn, "/settings/instance/configuration")

      assert has_element?(view, "a[href='#{@instance_settings}']", "Widgets")

      # the About settings had their own Spotlight and groups toggles, writing the same keys as the homepage's widget rows
      {:ok, view, _html} = live(admin_conn, "/settings/instance/about")

      assert has_element?(
               view,
               "[data-role=homepage_widgets_link][href='#{@instance_settings}?place=home']"
             )

      refute has_element?(view, "input[name*='HomeLive'][name*='instance_pinned']")
    end

    test "it has a tab for the homepage, which only offers widgets visitors can see", %{
      admin_conn: admin_conn
    } do
      {:ok, view, _html} = live(admin_conn, @instance_settings)

      assert has_element?(view, "#{@main_area} [data-widget-id=trending_discussions]")
      assert has_element?(view, "#{@sidebar_area} [data-widget-id=community_rules]")
      assert has_element?(view, "a[href='#{@instance_settings}?place=home']", "Homepage")

      {:ok, view, _html} = live(admin_conn, "#{@instance_settings}?place=home")

      # one area, as the homepage has: tiles, and the rest in its Add sheet
      refute has_element?(view, @sidebar_area)
      open_add(view, "main")

      assert has_element?(view, "#{@main_area} [data-widget-id=welcome]") or
               has_element?(view, "[data-role=add_widget_card][data-widget-id=welcome]")

      refute has_element?(view, "[data-widget-id=trending_discussions]")
    end

    test "an admin writes a custom widget there, adds it to the homepage, and visitors see it", %{
      admin_conn: admin_conn
    } do
      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets], main: [])

      # instance settings are mirrored into the global Application env, which the sandbox doesn't roll back
      on_exit(fn -> clear_instance_dashboard_settings([[Bonfire.UI.Common.Widgets, :custom]]) end)

      {:ok, view, _html} = live(admin_conn, "#{@instance_settings}?place=home")

      # the form is at the end of the main area's Add sheet
      open_add(view, "main")
      assert has_element?(view, "[data-role=custom_widget]", "Write your own widget")

      view
      |> form("form[data-scope=custom_widget_text]", %{
        "Bonfire.UI.Common.Widgets" => %{
          "custom" => %{
            "text" => %{
              "title" => "Start here",
              "text" => "Hello **visitors**\n\n![Our garden](https://example.local/garden.png)"
            }
          }
        }
      })
      |> render_submit()

      assert %{name: "Start here"} =
               Enum.find(Bonfire.UI.Common.Widgets.registry(), &(&1.id == :custom_text))

      # saving closes the sheet; reopened, it offers the new widget
      open_add(view, "main")
      add(view, "custom_text", "main")
      assert List.last(tile_ids(view, @main_area)) == "custom_text"

      Phoenix.ConnTest.build_conn()
      |> get_conn_render("/")
      |> assert_has("#home_main_widgets strong", text: "visitors")
      # markdown images, by URL, as the form has no upload
      |> assert_has(
        "#home_main_widgets img[src='https://example.local/garden.png'][alt='Our garden']"
      )
    end

    test "an admin turns off recent activity in the homepage tab, and visitors don't get it", %{
      admin_conn: admin_conn
    } do
      Phoenix.ConnTest.build_conn()
      |> get_conn_render("/")
      |> assert_has("#feed_heading")

      {:ok, view, _html} = live(admin_conn, "#{@instance_settings}?place=home")
      remove(view, "feed")

      Phoenix.ConnTest.build_conn()
      |> get_conn_render("/")
      |> refute_has("#feed_heading")
    end

    test "the homepage tab's refresh button purges the homepage from caches, for admins only", %{
      admin_conn: admin_conn,
      conn: conn
    } do
      Process.register(self(), :widgets_http_purge_test)

      Process.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [
        Bonfire.UI.Me.Test.RecordingHTTPPurge
      ])

      {:ok, view, _html} = live(admin_conn, "#{@instance_settings}?place=home")

      view
      |> element("[data-role=refresh_homepage]")
      |> render_click()

      assert_receive {:bust_urls, urls}, 1_000
      assert "/" in urls and "/about" in urls

      # someone who isn't an admin gets no button (instance settings only need an account for now; once they need an admin, this is a refused mount)
      {:ok, view, _html} = live(conn, "#{@instance_settings}?place=home")
      refute has_element?(view, "[data-role=refresh_homepage]")
    end

    test "the refresh button clears the saved copies of the homepage that guests are served, even with no proxy set up",
         %{admin_conn: admin_conn} do
      # a stand-in for `priv/static/public`, which guests are always served from when a page is saved there
      dir = Path.join(System.tmp_dir!(), "widgets_static_#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf(dir) end)

      for path <- ["index.html", "about/index.html"] do
        File.mkdir_p!(Path.dirname(Path.join(dir, path)))
        File.write!(Path.join(dir, path), "a homepage saved before the change")
      end

      Process.put(
        [:bonfire_ui_common, Bonfire.UI.Common.StaticGenerator, :output_dir],
        dir
      )

      # only the no-op adapter, as on an instance with no proxy or CDN
      Process.put([:bonfire_common, Bonfire.Common.Cache.HTTPPurge, :adapters], [
        Bonfire.Common.Cache.HTTPPurge.Null
      ])

      {:ok, view, _html} = live(admin_conn, "#{@instance_settings}?place=home")

      view
      |> element("[data-role=refresh_homepage]")
      |> render_click()

      refute File.exists?(Path.join(dir, "index.html"))
      refute File.exists?(Path.join(dir, "about/index.html"))
    end

    test "turning a widget on in the homepage tab shows it to visitors, and leaves the dashboard alone",
         %{admin_conn: admin_conn, user: user} do
      Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets], main: [])

      dashboard_before =
        Enum.map(
          Bonfire.UI.Common.Widgets.for_place({Bonfire.Web.Views.DashboardLive, :main}, user),
          & &1.id
        )

      refute :community_links in Enum.map(
               Bonfire.UI.Common.Widgets.for_place({Bonfire.Web.Views.HomeLive, :main}, nil),
               & &1.id
             )

      {:ok, view, _html} = live(admin_conn, "#{@instance_settings}?place=home")
      open_add(view, "main")
      add(view, "community_links", "main")

      assert :community_links in Enum.map(
               Bonfire.UI.Common.Widgets.for_place({Bonfire.Web.Views.HomeLive, :main}, nil),
               & &1.id
             )

      assert Enum.map(
               Bonfire.UI.Common.Widgets.for_place(
                 {Bonfire.Web.Views.DashboardLive, :main},
                 user
               ),
               & &1.id
             ) == dashboard_before
    end
  end

  describe "choices" do
    test "a key nobody declares is skipped", %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:no_such_widget, :suggested_profiles]
      )

      assert [%{key: :suggested_profiles}] = shown(me)
    end

    test "widgets for signed-in people are not offered to guests" do
      refute Enum.any?(options(nil), &(&1.key == :trending_discussions))
    end
  end
end
