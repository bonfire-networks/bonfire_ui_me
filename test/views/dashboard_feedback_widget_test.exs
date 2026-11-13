defmodule Bonfire.UI.Me.DashboardFeedbackWidgetTest do
  @moduledoc "A flavour puts the feedback widget in the dashboard sidebar by listing it in its config, `config :bonfire, Bonfire.Web.Views.DashboardLive, widgets: [sidebar: [:wishes]]`."
  use Bonfire.UI.Me.ConnCase, async: true
  @moduletag :ui

  setup do
    account = fake_account!()
    me = fake_user!(account)

    # Config.get reads these per test process
    Process.put(
      [:bonfire_ui_common, Bonfire.UI.Common.WidgetFeedbackLive, :url],
      "https://wishes.example.local/form"
    )

    {:ok, conn: conn(user: me, account: account)}
  end

  test "shows in the dashboard sidebar when the flavour lists it", %{conn: conn} do
    Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets], sidebar: [:wishes])

    conn
    |> visit("/dashboard")
    |> wait_async()
    |> assert_has("[data-id=widget_feedback] a[href='https://wishes.example.local/form']")
  end

  test "stays out when the flavour doesn't list it", %{conn: conn} do
    Process.put([:bonfire, Bonfire.Web.Views.DashboardLive, :widgets], sidebar: [])

    conn
    |> visit("/dashboard")
    |> wait_async()
    |> refute_has("[data-id=widget_feedback]")
  end
end
