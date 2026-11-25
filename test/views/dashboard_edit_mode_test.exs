defmodule Bonfire.UI.Me.DashboardEditModeTest do
  @moduledoc "Edit mode: a member changes their dashboard's widgets on the dashboard itself, and the settings page shows the same choices."
  use Bonfire.UI.Me.ConnCase, async: false

  @keys [:bonfire, Bonfire.Web.Views.DashboardLive, :widgets]
  @settings "/settings/user/dashboard"
  @main "[data-id=dashboard_main]"
  @sidebar "[data-id=secondary_sidebar_widgets]"

  setup do
    Process.put(@keys,
      main: [:suggested_profiles, :instance_pinned],
      sidebar: [:community_rules, :mods, :trending_links]
    )

    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  # the ids of the widgets in an area of a rendered dashboard, in order
  defp area_ids(html, area_selector) do
    html
    |> Floki.parse_document!()
    |> Floki.find("#{area_selector} [data-widget-id]")
    |> Enum.flat_map(&Floki.attribute(&1, "data-widget-id"))
  end

  defp fresh_area_ids(conn, area_selector) do
    {:ok, _view, html} = live(conn, "/dashboard")
    area_ids(html, area_selector)
  end

  # an area's draggable list on the dashboard: its `data-parent` and the `data-item` of each widget, as the Draggable hook reads them
  defp list(html, area_selector) do
    [list] =
      html |> Floki.parse_document!() |> Floki.find("#{area_selector} ul[phx-hook=Draggable]")

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

  # what the Draggable hook sends on a drop
  defp drop(view, area_selector, event, params) do
    view
    |> element("#{area_selector} ul[phx-hook=Draggable]")
    |> render_hook(event, params)
  end

  # guests don't get the dashboard (they're sent to log in), so they're checked on the guest homepage
  test "a member has a Customize button under the sidebar widgets, a guest doesn't", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, "/dashboard")
    assert html =~ ~s(data-role="customize_widgets")

    {:ok, _view, html} = live(Phoenix.ConnTest.build_conn(), "/")
    refute html =~ ~s(data-role="customize_widgets")
  end

  test "each widget's edit mode tile sketches the shape its declaration names", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    assert has_element?(view, "[data-widget-id=mods] [data-role=widget-skeleton][data-shape=people]")
    assert has_element?(view, "[data-widget-id=community_rules] [data-role=widget-skeleton][data-shape=list]")
  end

  test "removing a widget takes it off that member's dashboard only, and settings shows it off",
       %{conn: conn} do
    other_account = fake_account!()
    other_conn = conn(user: fake_user!(other_account), account: other_account)

    {:ok, view, _html} = live(conn, "/dashboard")

    view |> element("[data-role=remove_widget][phx-value-id=mods]") |> render_click()

    refute "mods" in area_ids(render(view), @sidebar)
    refute "mods" in fresh_area_ids(conn, @sidebar)
    assert "community_rules" in fresh_area_ids(conn, @sidebar)
    assert "mods" in fresh_area_ids(other_conn, @sidebar)

    conn
    |> visit(@settings)
    |> refute_has("#dashboard_sidebar_widget_toggle_mods[checked]")
  end

  test "Undo in the edit bar puts a removed widget back where it was", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    before = fresh_area_ids(conn, @sidebar)

    view |> element("[data-role=remove_widget][phx-value-id=mods]") |> render_click()
    assert has_element?(view, "[data-role=widgets_edit_bar]", "Moderators")

    view |> element("[data-role=undo_remove_widget]") |> render_click()

    assert area_ids(render(view), @sidebar) == before
    assert fresh_area_ids(conn, @sidebar) == before
    refute has_element?(view, "[data-role=undo_remove_widget]")
  end

  test "the sidebar's Add slot lists only the widgets not on the dashboard that fit the sidebar, and adding one puts it last there",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    view
    |> element("[data-role=add_widgets][data-area=sidebar] [data-role=open_modal]")
    |> render_click()

    assert has_element?(view, "[data-role=add_widget_card][data-widget-id=recent_users]")
    assert has_element?(view, "[data-role=add_widget_card][data-widget-id=recent_users]", "Recently joined")
    refute has_element?(view, "[data-role=add_widget_card][data-widget-id=mods]")
    refute has_element?(view, "[data-role=add_widget_card][data-widget-id=suggested_profiles]")
    # the Introduction is for the main area only
    refute has_element?(view, "[data-role=add_widget_card][data-widget-id=intro]")

    view
    |> element("[data-role=add_widget][phx-value-id=recent_users][phx-value-area=sidebar]")
    |> render_click()

    assert List.last(area_ids(render(view), @sidebar)) == "recent_users"
    assert List.last(fresh_area_ids(conn, @sidebar)) == "recent_users"
  end

  test "dragging a widget within the main area saves the order, and settings shows it", %{
    conn: conn
  } do
    {:ok, view, html} = live(conn, "/dashboard")
    assert ["suggested_profiles", "instance_pinned"] = area_ids(html, @main)

    %{parent: parent, event: event, items: items} = list(html, @main)
    swapped = [items["instance_pinned"], items["suggested_profiles"]]

    drop(view, @main, event, %{
      "old_index" => 1,
      "new_index" => 0,
      "parent_item" => parent,
      "source_item" => items["instance_pinned"],
      "target_parent" => parent,
      "target_order" => swapped
    })

    assert ["instance_pinned", "suggested_profiles"] == fresh_area_ids(conn, @main)

    {:ok, settings, _html} = live(conn, @settings)

    assert ["instance_pinned", "suggested_profiles"] ==
             settings
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("#dashboard-widgets [data-role=place_widget]")
             |> Enum.flat_map(&Floki.attribute(&1, "data-item"))
             |> Enum.filter(&(&1 in ["instance_pinned", "suggested_profiles"]))
  end

  test "a sidebar widget dragged into the main area moves there, and one too wide for the sidebar goes back",
       %{conn: conn} do
    {:ok, view, html} = live(conn, "/dashboard")
    main = list(html, @main)
    sidebar = list(html, @sidebar)

    # Moderators fits either area
    drop(view, @sidebar, sidebar.event, %{
      "old_index" => 1,
      "new_index" => 1,
      "parent_item" => sidebar.parent,
      "source_item" => sidebar.items["mods"],
      "target_parent" => main.parent,
      "target_order" => [main.items["suggested_profiles"], sidebar.items["mods"], main.items["instance_pinned"]]
    })

    assert ["suggested_profiles", "mods", "instance_pinned"] == fresh_area_ids(conn, @main)
    refute "mods" in fresh_area_ids(conn, @sidebar)

    # the Spotlight is only for the main area
    {:ok, view, html} = live(conn, "/dashboard")
    main = list(html, @main)
    sidebar = list(html, @sidebar)
    sidebar_before = area_ids(html, @sidebar)

    drop(view, @main, main.event, %{
      "old_index" => 2,
      "new_index" => 0,
      "parent_item" => main.parent,
      "source_item" => main.items["instance_pinned"],
      "target_parent" => sidebar.parent,
      "target_order" => [main.items["instance_pinned"] | Map.values(sidebar.items)]
    })

    # the hook puts it back when told the drop was refused
    assert_reply(view, %{refused: true})
    assert "instance_pinned" in fresh_area_ids(conn, @main)
    assert fresh_area_ids(conn, @sidebar) == sidebar_before
  end

  test "a refused drop keeps the Undo of a widget removed just before", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    view |> element("[data-role=remove_widget][phx-value-id=mods]") |> render_click()

    html = render(view)
    main = list(html, @main)
    sidebar = list(html, @sidebar)

    # the Spotlight is only for the main area
    drop(view, @main, main.event, %{
      "old_index" => 1,
      "new_index" => 0,
      "parent_item" => main.parent,
      "source_item" => main.items["instance_pinned"],
      "target_parent" => sidebar.parent,
      "target_order" => [main.items["instance_pinned"] | Map.values(sidebar.items)]
    })

    assert has_element?(view, "[data-role=undo_remove_widget]")
  end

  test "dragging a widget keeps the Undo of a widget removed just before", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")
    view |> element("[data-role=remove_widget][phx-value-id=mods]") |> render_click()

    %{parent: parent, event: event, items: items} = list(render(view), @main)

    drop(view, @main, event, %{
      "old_index" => 1,
      "new_index" => 0,
      "parent_item" => parent,
      "source_item" => items["instance_pinned"],
      "target_parent" => parent,
      "target_order" => [items["instance_pinned"], items["suggested_profiles"]]
    })

    assert has_element?(view, "[data-role=undo_remove_widget]")
  end

  test "adding a widget to an area it doesn't fit says so", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/dashboard")

    # as from a sheet rendered before the widget stopped fitting: the Introduction is for the main area only
    html =
      render_click(view, "Bonfire.UI.Common.Widgets:add", %{"id" => "intro", "area" => "sidebar"})

    assert html =~ "This widget can&#39;t be added there any more."
    refute "intro" in fresh_area_ids(conn, @sidebar)
  end

  test "choosing a feed from the Feed widget's settings in edit mode changes the dashboard's feed",
       %{conn: conn, me: me} do
    Process.put(@keys, main: [:feed], sidebar: [:community_rules])

    # a feed no fallback would pick; keep the user the put returns, as settings are preloaded on it
    name = Faker.Lorem.sentence()

    {:ok, _} =
      Bonfire.Common.Settings.put(
        [:bonfire_social, Bonfire.Social.Feeds, :feed_presets, :dashboard_custom],
        %{
          name: name,
          icon: "ph:rss-simple-fill",
          exclude_from_nav: true,
          filters: %{feed_name: :local}
        },
        current_user: me
      )

    conn
    |> visit("/dashboard")
    |> PhoenixTest.select("[data-role=widget-edit-controls] select", "Feed shown on the dashboard",
      option: name
    )
    |> visit("/dashboard")
    |> assert_has("[data-id=feed] #feed-tab-dashboard_custom[aria-current=page]")
    # the tile's chip names the chosen feed
    |> assert_has("[data-widget-id=feed] [data-role=widget-setting-chip]", text: name)
  end
end
