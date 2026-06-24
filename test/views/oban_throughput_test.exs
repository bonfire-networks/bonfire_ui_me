defmodule Bonfire.UI.Me.ObanThroughputTest do
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Common.Config
  alias Bonfire.Common.ObanPresets

  @path "/settings/instance/configuration"

  setup do
    account = fake_account!()
    admin = fake_admin!(account)

    on_exit(fn ->
      Config.delete([ObanPresets, :preset])
      Config.delete([ObanPresets, :queues])
      Config.delete([ObanPresets, :prioritised_groups])
    end)

    {:ok, conn: conn(user: admin, account: account)}
  end

  test "an admin sees the throughput preset cards and the advanced per-queue editor", %{
    conn: conn
  } do
    conn
    |> visit(@path)
    |> wait_async()
    |> assert_has("[data-role=oban_throughput]")
    |> assert_has("[data-role=oban_preset]", text: "Eco")
    |> assert_has("[data-role=oban_preset]", text: "Default")
    |> assert_has("[data-role=oban_preset]", text: "Turbo")
    # Layer 3: the advanced per-queue editor + a row per managed queue
    |> assert_has("[data-role=oban_throughput_advanced]")
    |> assert_has("[data-role=oban_queue_row]")
  end

  test "switching the preset to Eco persists the instance setting", %{conn: conn} do
    conn
    |> visit(@path)
    |> wait_async()
    |> choose("Eco", exact: false)

    assert ObanPresets.current_preset() == :eco
  end

  test "editing a per-queue override switches to the Custom preset and persists", %{conn: conn} do
    conn
    |> visit(@path)
    |> wait_async()
    |> within("[data-role=oban_throughput_advanced]", fn session ->
      fill_in(session, "federator_outgoing", with: "1")
    end)

    assert ObanPresets.current_preset() == :custom
    assert ObanPresets.current_overrides()[:federator_outgoing] == 1
  end

  test "prioritising a group persists", %{conn: conn} do
    conn
    |> visit(@path)
    |> wait_async()
    |> check("Mentions & follows", exact: false)

    assert ObanPresets.current_priorities()[:interactions] == true
  end
end
