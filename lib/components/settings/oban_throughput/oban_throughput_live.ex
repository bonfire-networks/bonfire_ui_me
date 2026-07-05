defmodule Bonfire.UI.Me.SettingsViewsLive.ObanThroughputLive do
  @moduledoc """
  Admin control to pick the **background-processing throughput presets** (#1638) — how much federation/import/etc. Oban work runs at once, to keep a server responsive under load.

  Composes the shared calm-empowerment components (`Bonfire.UI.Common.Settings.Calm.{PresetCardsLive, OverrideTogglesLive, AdvancedKnobsLive}`) over `Bonfire.Common.ObanPresets` — the first consumer of the pattern, and the reference for others (see `Bonfire.Common.Settings.Calm`). Everything persists via the `Bonfire.Common.Settings:set` funnel; the save hook rescales the live queues.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Common.ObanPresets

  # throughput is a server-wide (instance) concern
  prop scope, :atom, default: :instance

  @doc "Currently-effective preset, as a string for seeding the `checked` radio."
  def current_preset, do: to_string(ObanPresets.current_preset())

  @doc "The preset cards (name, icon, description) in the configured order — metadata from config `:cards`."
  def preset_cards do
    cards = ObanPresets.cards()

    Enum.map(ObanPresets.preset_names(), fn name ->
      meta = Keyword.get(cards, name, [])

      %{
        value: to_string(name),
        name: Keyword.get(meta, :name) || Phoenix.Naming.humanize(name),
        icon: Keyword.get(meta, :icon, "ph:gauge-duotone"),
        description: Keyword.get(meta, :description, "")
      }
    end)
  end

  @doc "Form field name that maps to the `[Bonfire.Common.ObanPresets, :preset]` setting."
  def field_name, do: "#{ObanPresets}[preset]"

  @doc "Form field prefix for the `:queues` overrides map (whole-map name clears it; per-queue via the components)."
  def queues_field, do: "#{ObanPresets}[queues]"

  @doc "Form field prefix for the `:prioritised_groups` toggles."
  def priorities_prefix, do: "#{ObanPresets}[prioritised_groups]"

  @doc """
  One row per managed queue with its current effective limit (prefill for the advanced editor),
  a human label where configured (`:queue_labels`), and the technical queue name in a tooltip.
  """
  def queue_rows do
    effective = ObanPresets.effective_limits()
    labels = Bonfire.Common.Config.get([ObanPresets, :queue_labels], [])

    Enum.map(ObanPresets.managed_queues(), fn queue ->
      %{
        name: queue,
        label: Keyword.get(labels, queue),
        tooltip: to_string(queue),
        value: Map.get(effective, queue, 1)
      }
    end)
  end

  @doc "Layer 2 — one row per federation queue group, with whether it's currently prioritised."
  def group_rows do
    priorities = ObanPresets.current_priorities()

    Enum.map(ObanPresets.queue_groups(), fn {group, meta} ->
      %{
        key: group,
        name: Keyword.get(meta, :name) || Phoenix.Naming.humanize(group),
        description: Keyword.get(meta, :description, ""),
        on: Map.get(priorities, group, false)
      }
    end)
  end
end
