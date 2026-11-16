defmodule Bonfire.UI.Me.LayoutFeedbackWidgetTest do
  @moduledoc "A flavour puts the feedback widget on every page by listing it in its config, `config :bonfire_ui_common, Bonfire.UI.Common.LayoutLive, widgets: [layout: [:wishes]]`, and an admin can turn it off with `[Bonfire.UI.Common.LayoutLive, :include, :wishes]`."
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

  @widget "[data-id=widget_feedback] a[href='https://wishes.example.local/form']"

  test "shows on a page that sets its own sidebar widgets when the flavour lists it", %{
    conn: conn
  } do
    Process.put([:bonfire_ui_common, Bonfire.UI.Common.LayoutLive, :widgets], layout: [:wishes])

    conn
    |> visit("/user")
    |> wait_async()
    |> assert_has(@widget)
  end

  test "stays out when the flavour doesn't list it", %{conn: conn} do
    Process.put([:bonfire_ui_common, Bonfire.UI.Common.LayoutLive, :widgets], layout: [])

    conn
    |> visit("/user")
    |> wait_async()
    |> refute_has("[data-id=widget_feedback]")
  end

  test "stays out when turned off", %{conn: conn} do
    Process.put([:bonfire_ui_common, Bonfire.UI.Common.LayoutLive, :widgets], layout: [:wishes])
    Process.put([:bonfire_ui_common, Bonfire.UI.Common.LayoutLive, :include, :wishes], false)

    conn
    |> visit("/user")
    |> wait_async()
    |> refute_has("[data-id=widget_feedback]")
  end
end
