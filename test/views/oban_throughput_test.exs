defmodule Bonfire.UI.Me.ObanThroughputTest do
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Common.Config
  alias Bonfire.Common.ObanPresets

  @path "/settings/instance/configuration"

  setup do
    account = fake_account!()
    admin = fake_admin!(account)

    # These settings persist through the instance-scope funnel, which mirrors into GLOBAL
    # Application env (NOT rolled back by the Ecto sandbox). Clear the leaf keys both before
    # and after each test so ordering can't leak state between these async:false tests (a
    # preset pick's `clear_field` leaves e.g. `queues: ""`, and the next write deep-merges
    # its map into that stale scalar → an empty read).
    #
    # NB: these settings live under ObanPresets' OWN otp_app (resolved via `keys_tree`), not
    # the top-level app `Config.delete/1` assumes — pass it explicitly, or the delete silently
    # no-ops against the wrong app and the leak survives.
    [otp_app | _] = Config.keys_tree(ObanPresets)

    clear_oban_settings = fn ->
      Config.delete([ObanPresets, :preset], otp_app)
      Config.delete([ObanPresets, :queues], otp_app)
      Config.delete([ObanPresets, :prioritised_groups], otp_app)
    end

    clear_oban_settings.()
    on_exit(clear_oban_settings)

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
    # scoped: the InstanceTuning card on the same page also has an "Eco" radio
    |> within("[data-role=oban_throughput]", fn session ->
      choose(session, "Eco", exact: false)
    end)

    assert ObanPresets.current_preset() == :eco
  end

  test "editing a per-queue override switches to the Custom preset and persists", %{conn: conn} do
    conn
    |> visit(@path)
    |> wait_async()
    |> within("[data-role=oban_throughput_advanced]", fn session ->
      # human label (queue_labels config); technical queue name lives in the row tooltip
      fill_in(session, "Outgoing deliveries", with: "1")
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
