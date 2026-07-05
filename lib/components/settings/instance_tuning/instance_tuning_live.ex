defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceTuningLive do
  @moduledoc """
  Admin card for **instance performance tuning** (plan: postgres-ops-tuning.md › C2) — presets, outcome-named override toggles, and the advanced per-knob editor over `Bonfire.Common.Settings.Calm.InstanceTuning` (currently the Postgres layer, applied live via whitelisted `ALTER SYSTEM` + reload).

  Composes the shared calm-empowerment components; everything persists via the `Bonfire.Common.Settings:set` funnel and the save hook applies the diff live. Knobs needing a DB restart surface as a pending-restart notice (never auto-restarted).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.Settings.Calm.InstanceTuning

  # server tuning is an instance-wide concern
  prop scope, :atom, default: :instance

  @doc "Currently-effective preset, as a string for seeding the `checked` radio."
  def current_preset, do: to_string(InstanceTuning.current_preset())

  @doc "The preset cards (name, icon, description) in the configured order."
  def preset_cards do
    cards = InstanceTuning.cards()

    Enum.map(InstanceTuning.preset_names(), fn name ->
      meta = Keyword.get(cards, name, [])

      %{
        value: to_string(name),
        name: Keyword.get(meta, :name) || Phoenix.Naming.humanize(name),
        icon: Keyword.get(meta, :icon, "ph:gauge-duotone"),
        description: Keyword.get(meta, :description, "")
      }
    end)
  end

  @doc "Form field name for the preset setting."
  def field_name, do: "#{InstanceTuning}[preset]"

  @doc "Form field prefix for the sparse Level-3 knob values (whole-map name clears them)."
  def knobs_field, do: "#{InstanceTuning}[knobs]"

  @doc "Form field prefix for the Level-2 override toggles."
  def overrides_prefix, do: "#{InstanceTuning}[overrides]"

  @doc "Level 2 — one row per override toggle, with whether it's currently on."
  def group_rows do
    overrides = InstanceTuning.current_overrides()

    Enum.map(InstanceTuning.toggle_groups(), fn {group, meta} ->
      %{
        key: group,
        name: Keyword.get(meta, :name) || Phoenix.Naming.humanize(group),
        description: Keyword.get(meta, :description, ""),
        on: Map.get(overrides, group, false)
      }
    end)
  end

  @doc "Level 3 — one row per registry knob with its current EFFECTIVE value (composition made visible)."
  def knob_rows do
    effective = InstanceTuning.effective()

    Enum.map(InstanceTuning.registry(), fn {knob, spec} ->
      value = Map.get(effective, knob)

      case Keyword.get(spec, :type, :int) do
        :bool ->
          %{name: knob, value: value || "off", kind: :bool}

        :real ->
          %{name: knob, value: value || 0, step: "any", min: bounds_min(spec)}

        _ ->
          %{name: knob, value: value || 0, min: bounds_min(spec)}
      end
    end)
  end

  defp bounds_min(spec) do
    case Keyword.get(spec, :bounds) do
      {lo, _hi} -> lo
      _ -> nil
    end
  end

  @doc "Knobs persisted but awaiting a DB restart (shown as a notice, never auto-restarted)."
  def pending_restart, do: InstanceTuning.pending_restart()
end
