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

  @doc """
  Level 3 — one row per registry knob with its current EFFECTIVE value (composition made visible),
  the human label + unit, and the technical GUC name in a tooltip for techies.
  """
  def knob_rows do
    effective = InstanceTuning.effective()
    stored = InstanceTuning.current_knobs()

    for {knob, spec} <- InstanceTuning.registry(), !Keyword.get(spec, :read_only) do
      value = Map.get(effective, knob)

      base = %{
        name: knob,
        label: Keyword.get(spec, :name),
        tooltip: knob_tooltip(knob, spec),
        unit: Keyword.get(spec, :unit),
        # human meaning when the value is a sentinel (e.g. -1 = disabled)
        note: get_in(spec, [:sentinels, value])
      }

      cond do
        choices = Keyword.get(spec, :choices) ->
          # sentinel-capable knob: curated labeled choices instead of magic -1/0 numbers
          # (the label already carries the meaning + unit, so note/unit would be redundant)
          Map.merge(base, %{
            kind: :choices,
            value: value,
            choices: with_current_choice(choices, value),
            note: nil,
            unit: nil
          })

        Keyword.get(spec, :relative) ->
          # stored as % of the tuner's baseline (slider) with a live preview of what
          # that means in real units right now — recomputes if the machine changes
          Map.merge(base, %{
            kind: :percent,
            value: Map.get(stored, knob, 100),
            preview: "= #{value || 0} #{Keyword.get(spec, :unit)}"
          })

        Keyword.get(spec, :type, :int) == :bool ->
          Map.merge(base, %{value: value || "off", kind: :bool})

        Keyword.get(spec, :type, :int) == :enum ->
          Map.merge(base, %{value: value, kind: :enum, values: Keyword.get(spec, :values, [])})

        Keyword.get(spec, :type, :int) == :real ->
          Map.merge(base, %{value: value || 0, step: "any", min: bounds_min(spec)})

        true ->
          Map.merge(base, %{value: value || 0, min: bounds_min(spec)})
      end
    end
  end

  @doc """
  The read-only boot/deploy rows (their own section): value from the env var when set, else a
  LIVE source (e.g. the running Repo's config) or an honest documented default — never a bare
  "default" placeholder.
  """
  def readonly_rows do
    for {knob, spec} <- InstanceTuning.registry(), Keyword.get(spec, :read_only) do
      env = Keyword.get(spec, :env)

      value =
        System.get_env(env) ||
          repo_config_value(Keyword.get(spec, :repo_key)) ||
          Keyword.get(spec, :display_default) ||
          l("auto-detected")

      %{
        name: knob,
        label: Keyword.get(spec, :name),
        kind: :read_only,
        value: value,
        unit: Keyword.get(spec, :unit),
        tooltip:
          "#{env} " <> l("(read only: set by developers in code or sysadmins in server config)")
      }
    end
  end

  # keep the select honest when the effective value (e.g. from the boot baseline or an old
  # manual entry) isn't one of the curated choices: show it as an extra selected option
  defp with_current_choice(choices, value) do
    if is_nil(value) or Enum.any?(choices, fn {v, _} -> v == value end),
      do: choices,
      else: choices ++ [{value, l("current: %{value}", value: value)}]
  end

  defp repo_config_value(nil), do: nil

  defp repo_config_value(key) do
    case Keyword.get(Bonfire.Common.Repo.config(), key) do
      nil -> nil
      value -> to_string(value)
    end
  rescue
    _ -> nil
  end

  defp knob_tooltip(knob, spec) do
    sentinels =
      case Keyword.get(spec, :sentinels) do
        %{} = sentinels ->
          " · " <> Enum.map_join(sentinels, ", ", fn {v, label} -> "#{v} = #{label}" end)

        _ ->
          ""
      end

    "#{knob} (#{Keyword.get(spec, :context, :live)})#{sentinels}"
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
