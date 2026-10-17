defmodule Bonfire.UI.Me.DashboardSettingsTest do
  @moduledoc "Dashboard settings: what's changed there is what the dashboard renders."
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.UI.Me.Dashboard

  @settings "/settings/user/dashboard"

  setup do
    account = fake_account!()
    me = fake_user!(account)

    {:ok, conn: conn(user: me, account: account), me: me}
  end

  defp options(me), do: Dashboard.options(maybe_apply(Bonfire.Web.Views.DashboardLive, :main_widget_choices, []), me)

  # positions of the main-area widgets as the dashboard renders them
  defp dashboard_order(conn) do
    {:ok, _view, html} = live(conn, "/dashboard")

    html
    |> Floki.parse_document!()
    |> Floki.find("#dashboard_main_widgets [data-item]")
    |> Enum.flat_map(&Floki.attribute(&1, "data-item"))
  end

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

  test "lists every main-area widget the dashboard offers", %{
    conn: conn,
    me: me
  } do
    assert [_, _ | _] = options(me), "needs at least two widgets to be worth testing"

    {:ok, view, _html} = live(conn, @settings)

    for option <- options(me) do
      assert has_element?(view, "#dashboard-widget-#{option.key}", option.name)
    end

    rows =
      view
      |> render()
      |> Floki.parse_document!()
      |> Floki.find("[data-role=dashboard_widget]")

    assert length(rows) == length(options(me))
  end

  test "hiding a widget in settings takes it off the dashboard", %{conn: conn, me: me} do
    %{name: name, widget: widget} = List.last(options(me))
    module = widget.module

    assert to_string(module) in dashboard_order(conn)

    conn
    |> visit(@settings)
    |> uncheck(name, exact: false)

    refute to_string(module) in dashboard_order(conn)
  end

  test "moving a widget in settings moves it on the dashboard", %{conn: conn, me: me} do
    [first, second | _] = options(me)
    first_module = first.widget.module |> to_string()
    second_module = second.widget.module |> to_string()

    assert [^first_module, ^second_module | _] = dashboard_order(conn)

    {:ok, view, _html} = live(conn, @settings)

    view
    |> element("#dashboard-widget-#{first.key} [data-role=move_down]")
    |> render_click()

    # the list in settings follows straight away
    assert [_, moved | _] =
             view
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("[data-role=dashboard_widget]")
             |> Enum.flat_map(&Floki.attribute(&1, "data-item"))

    assert moved == to_string(first.key)

    assert [^second_module, ^first_module | _] = dashboard_order(conn)
  end

  test "the first widget can't move up, nor the last one down", %{conn: conn, me: me} do
    first = List.first(options(me))
    last = List.last(options(me))

    {:ok, view, _html} = live(conn, @settings)

    assert has_element?(view, "#dashboard-widget-#{first.key} [data-role=move_up][disabled]")
    assert has_element?(view, "#dashboard-widget-#{last.key} [data-role=move_down][disabled]")
  end

  describe "the latest-activity feed" do
    defp dashboard_html(conn) do
      {:ok, _view, html} = live(conn, "/dashboard")
      html
    end

    defp has_feed?(html),
      do: Floki.find(Floki.parse_document!(html), "[data-id=dashboard_feed]") != []

    defp position(html, selector) do
      # where an element starts in the page, to compare which comes first
      [{_, attrs, _} | _] = Floki.find(Floki.parse_document!(html), selector)
      {"id", id} = List.keyfind(attrs, "id", 0) || {"id", nil}
      :binary.match(html, ~s(id="#{id}")) |> elem(0)
    end

    test "is off unless chosen", %{conn: conn} do
      refute has_feed?(dashboard_html(conn))
    end

    test "turned on in settings, it comes after every widget", %{conn: conn} do
      conn
      |> visit(@settings)
      |> check("Latest activity", exact: false)

      html = dashboard_html(conn)

      assert has_feed?(html)
      assert position(html, "#dashboard_main_widgets") < position(html, "#dashboard_feed_heading")
    end

    test "has a toggle in settings but no place in the order", %{conn: conn} do
      {:ok, view, _html} = live(conn, @settings)

      assert has_element?(view, "[data-role=dashboard_feed_setting]", "Latest activity")
      refute has_element?(view, "[data-role=dashboard_feed_setting] [data-role=move_up]")
      refute has_element?(view, "[data-role=dashboard_widget]", "Latest activity")
    end

    test "with every widget hidden, the dashboard is just the feed", %{conn: conn, me: me} do
      for %{key: key} <- options(me) do
        Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, key], false, current_user: me)
      end

      Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :include, :feed], true, current_user: me)

      html = dashboard_html(conn)

      assert has_feed?(html)
      refute html =~ "You can customise your dashboard"
    end

    test "whoever chose the old feed-only mode keeps a feed", %{conn: conn, me: me} do
      Bonfire.Common.Settings.put([Bonfire.Web.Views.DashboardLive, :default_feed], :my, current_user: me)

      assert has_feed?(dashboard_html(conn))
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
        Dashboard.save_order(
          [second, first | options(me) |> Enum.drop(2)],
          me
        )

      {:ok, view, _html} = live(conn, @settings)

      settings_modules =
        view
        |> render()
        |> Floki.parse_document!()
        |> Floki.find("[data-role=dashboard_widget]")
        |> Enum.flat_map(&Floki.attribute(&1, "data-item"))
        |> Enum.map(fn key ->
          Enum.find(options(me), &(to_string(&1.key) == key)).widget
          |> Map.fetch!(:module)
          |> to_string()
        end)

      assert settings_modules == dashboard_order(conn)
    end
  end

  describe "choices" do
    test "a key nobody describes is skipped", %{me: me} do
      assert [%{key: :suggested_profiles}] =
               Dashboard.options([:no_such_widget, :suggested_profiles], me)
    end

    test "widgets for signed-in people are not offered to guests" do
      refute Enum.any?(
               Dashboard.options(Dashboard.default_choices(), nil),
               &(&1.key == :trending_discussions)
             )
    end
  end
end
