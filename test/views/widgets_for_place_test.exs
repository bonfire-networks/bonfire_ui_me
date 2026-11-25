defmodule Bonfire.UI.Me.WidgetsForPlaceTest do
  @moduledoc "Which widgets a place (eg. the dashboard's main area or the guest home) shows, and in what order: the flavour's defaults, then the instance's choices, then each person's own."
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.UI.Common.Widgets
  alias Bonfire.Common.Config
  alias Bonfire.Common.Settings

  @dashboard {Bonfire.Web.Views.DashboardLive, :main}
  @home {Bonfire.Web.Views.HomeLive, :main}

  # instance settings are mirrored into the global Application env, which the sandbox doesn't roll back
  defp clear_instance(keys_list) do
    for keys <- keys_list, Config.get(keys, nil) != nil do
      [otp_app | keys] = Config.keys_tree(keys)
      Config.delete(keys, otp_app)
    end
  end

  setup do
    clear = fn ->
      clear_instance([
        [Bonfire.Web.Views.DashboardLive, :include],
        [Bonfire.Web.Views.HomeLive, :include],
        [:ui, :widget_order, :dashboard_main_widgets]
      ])
    end

    clear.()
    on_exit(clear)

    admin = fake_admin!(fake_account!())
    me = fake_user!(fake_account!())

    # the flavour's defaults, which Config.get reads per test process
    Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
      main: [:suggested_profiles, :trending_discussions]
    )

    {:ok, admin: admin, me: me}
  end

  defp widget_ids(widgets), do: Enum.map(widgets, & &1.id)

  test "a place shows the flavour's defaults, in their order", %{me: me} do
    assert widget_ids(Widgets.for_place(@dashboard, me)) == [
             :suggested_profiles,
             :trending_discussions
           ]
  end

  test "an instance's choice beats the flavour's, and a person's beats the instance's", %{
    admin: admin,
    me: me
  } do
    {:ok, _} =
      Settings.put([Bonfire.Web.Views.DashboardLive, :include, :trending_discussions], false,
        scope: :instance,
        current_user: admin
      )

    {:ok, _} =
      Settings.put([Bonfire.Web.Views.DashboardLive, :include, :polls_closing_soon], true,
        scope: :instance,
        current_user: admin
      )

    assert widget_ids(Widgets.for_place(@dashboard, me)) == [
             :suggested_profiles,
             :polls_closing_soon
           ]

    {:ok, %{__context__: %{current_user: me}}} =
      Settings.put([Bonfire.Web.Views.DashboardLive, :include, :trending_discussions], true,
        current_user: me
      )

    assert :trending_discussions in widget_ids(Widgets.for_place(@dashboard, me))
  end

  test "guests never get a widget only for signed-in people" do
    Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets],
      main: [:trending_discussions, :welcome]
    )

    assert widget_ids(Widgets.for_place(@home, nil)) == [:welcome]
  end

  test "a sidebar never gets a wide widget, and a main area gets both" do
    Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
      main: [:instance_pinned, :suggested_profiles],
      sidebar: [:instance_pinned, :suggested_profiles]
    )

    assert :instance_pinned in widget_ids(Widgets.offered(@dashboard, nil))

    refute :instance_pinned in widget_ids(
             Widgets.offered({Bonfire.Web.Views.DashboardLive, :sidebar}, nil)
           )
  end

  describe "a widget sits in one area of a page" do
    @sidebar {Bonfire.Web.Views.DashboardLive, :sidebar}

    test "a sidebar-only widget isn't offered on a page whose flavour lists no sidebar", %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles]
      )

      refute :trending_links in widget_ids(Widgets.offered(@dashboard, me))
      assert widget_ids(Widgets.offered(@sidebar, me)) == []
    end

    test "a sidebar-only widget is offered in the sidebar, and not in the main area", %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles],
        sidebar: [:trending_links]
      )

      assert :trending_links in widget_ids(Widgets.offered(@sidebar, me))
      refute :trending_links in widget_ids(Widgets.offered(@dashboard, me))
    end

    test "a main-only widget isn't offered in the sidebar, even when the flavour lists it there",
         %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles],
        sidebar: [:instance_pinned]
      )

      refute :instance_pinned in widget_ids(Widgets.offered(@sidebar, me))
      assert :instance_pinned in widget_ids(Widgets.offered(@dashboard, me))
    end

    test "a widget for either area that the flavour lists in the sidebar isn't offered in the main area",
         %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles],
        sidebar: [:community_rules]
      )

      assert :community_rules in widget_ids(Widgets.for_place(@sidebar, me))
      refute :community_rules in widget_ids(Widgets.offered(@dashboard, me))
    end

    test "a widget for either area that no list names goes to the first area, and a saved area moves it",
         %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles],
        sidebar: [:community_rules]
      )

      assert :welcome in widget_ids(Widgets.offered(@dashboard, me))
      refute :welcome in widget_ids(Widgets.offered(@sidebar, me))

      {:ok, %{__context__: %{current_user: me}}} =
        Settings.put([Bonfire.Web.Views.DashboardLive, :area, :community_rules], :main,
          current_user: me
        )

      assert :community_rules in widget_ids(Widgets.offered(@dashboard, me))
      refute :community_rules in widget_ids(Widgets.offered(@sidebar, me))

      # it's still on, as the flavour listed it
      assert :community_rules in widget_ids(Widgets.for_place(@dashboard, me))
    end

    test "a saved area the widget can't take is ignored", %{me: me} do
      Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets],
        main: [:suggested_profiles],
        sidebar: [:trending_links]
      )

      {:ok, %{__context__: %{current_user: me}}} =
        Settings.put([Bonfire.Web.Views.DashboardLive, :area, :trending_links], :main,
          current_user: me
        )

      assert :trending_links in widget_ids(Widgets.offered(@sidebar, me))
      refute :trending_links in widget_ids(Widgets.offered(@dashboard, me))
    end
  end

  test "a disabled widget is left out" do
    Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets],
      main: [:welcome, :instance_pinned]
    )

    assert :welcome in widget_ids(Widgets.for_place(@home, nil))

    # with no viewer, `module_enabled?` reads this from config
    Process.put(
      [:bonfire_ui_common, Bonfire.UI.Common.WidgetWelcomeLive, :modularity],
      :disabled
    )

    Bonfire.Common.Extend.clear_modularity_cache()

    refute :welcome in widget_ids(Widgets.for_place(@home, nil))
    assert :instance_pinned in widget_ids(Widgets.for_place(@home, nil))
  end

  test "a saved order beats the default order", %{me: me} do
    {:ok, %{__context__: %{current_user: me}}} =
      Bonfire.Common.Settings.LiveHandler.save_widget_order(
        :dashboard_main_widgets,
        [
          Bonfire.UI.Social.WidgetTrendingDiscussionsLive,
          Bonfire.UI.Social.WidgetSuggestedProfilesLive
        ],
        current_user: me
      )

    assert widget_ids(Widgets.for_place(@dashboard, me)) == [
             :trending_discussions,
             :suggested_profiles
           ]
  end

  test "offered lists every widget the place can have, with whether it's shown", %{me: me} do
    offered = Widgets.offered(@dashboard, me)

    assert %{included: true} = Enum.find(offered, &(&1.id == :suggested_profiles))
    assert %{included: false} = Enum.find(offered, &(&1.id == :groups))
  end

  test "a custom widget is offered in every place, and shown once included", %{admin: admin} do
    # none of the flavour's own, so only the custom one can show
    Process.put([:bonfire, Bonfire.Web.Views.HomeLive, :widgets], main: [])

    Process.put([:bonfire_ui_common, Bonfire.UI.Common.Widgets, :custom], %{
      text: %{title: "Start here", text: "Hello"}
    })

    assert %{included: false} = Enum.find(Widgets.offered(@home, nil), &(&1.id == :custom_text))

    {:ok, _} =
      Settings.put([Bonfire.Web.Views.HomeLive, :include, :custom_text], true,
        scope: :instance,
        current_user: admin
      )

    assert [%{id: :custom_text, module: Bonfire.UI.Common.WidgetTextLive, data: data}] =
             Widgets.for_place(@home, nil)

    assert data[:text] == "Hello"
  end
end
