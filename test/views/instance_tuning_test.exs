defmodule Bonfire.UI.Me.InstanceTuningTest do
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Common.Config
  alias Bonfire.Common.Settings.Calm.InstanceTuning

  @path "/settings/instance/configuration"

  setup do
    account = fake_account!()
    admin = fake_admin!(account)

    # a known baseline so preset/toggle transforms have something to work over
    # (the test env uses the DisabledApplier — no ALTER SYSTEM ever reaches the test DB)
    InstanceTuning.put_baseline(%{work_mem: 65_536, jit: "on", autovacuum_vacuum_cost_limit: 200})

    on_exit(fn ->
      Config.delete([InstanceTuning, :preset])
      Config.delete([InstanceTuning, :knobs])
      Config.delete([InstanceTuning, :overrides])
      InstanceTuning.reset_baseline()
    end)

    {:ok, conn: conn(user: admin, account: account)}
  end

  test "an admin sees the tuning preset cards, override toggles and the advanced knob editor", %{
    conn: conn
  } do
    conn
    |> visit(@path)
    |> wait_async()
    |> assert_has("[data-role=instance_tuning]")
    |> assert_has("[data-role=tuning_preset]", text: "Eco")
    |> assert_has("[data-role=tuning_preset]", text: "Turbo")
    |> assert_has("[data-role=tuning_override_group]", text: "Keep the database lean")
    |> assert_has("[data-role=instance_tuning_advanced]")
    |> assert_has("[data-role=tuning_knob_row]", text: "work_mem")
  end

  test "picking a preset persists it", %{conn: conn} do
    conn
    |> visit(@path)
    |> wait_async()
    |> within("[data-role=instance_tuning]", fn session ->
      choose(session, "Eco", exact: false)
    end)

    assert InstanceTuning.current_preset() == :eco
  end

  test "toggling an override persists it without changing the preset", %{conn: conn} do
    conn
    |> visit(@path)
    |> wait_async()
    |> within("[data-role=instance_tuning]", fn session ->
      check(session, "Keep the database lean", exact: false)
    end)

    # the UI funnel persisted the toggle
    assert InstanceTuning.current_overrides()[:lean_database] == true

    # effective-value composition is asserted with the toggle primed IN THIS process
    # (test-env Config.get reads the process tree first — the LV process's settings
    # writes aren't reliably visible here; the reducer itself is pinned in calm_test.exs)
    Process.put([InstanceTuning, :overrides], %{lean_database: true})
    assert InstanceTuning.effective()[:autovacuum_vacuum_cost_limit] == 2000
  end

  test "editing an advanced knob switches to the custom preset and stores the value", %{
    conn: conn
  } do
    conn
    |> visit(@path)
    |> wait_async()
    |> within("[data-role=instance_tuning_advanced]", fn session ->
      fill_in(session, "work_mem", with: "32768")
    end)

    assert InstanceTuning.current_preset() == :custom
    assert InstanceTuning.current_knobs()[:work_mem] == 32_768
  end
end
