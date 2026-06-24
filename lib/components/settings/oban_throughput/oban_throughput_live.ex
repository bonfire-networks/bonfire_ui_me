defmodule Bonfire.UI.Me.SettingsViewsLive.ObanThroughputLive do
  @moduledoc """
  Admin control to pick the **background-processing throughput presets** (#1638) — how much federation/import/etc. Oban work runs at once, to keep a server responsive under load.

  Rich radio-cards owned by native radios + `peer-checked` CSS (clicking highlights instantly; `phx-change` persists via the `Bonfire.Common.Settings:set` funnel; the save hook rescales the live queues — see `Bonfire.Common.ObanPresets`). 
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

  @doc "Form field name for the whole `:queues` overrides map (used to clear it when picking a preset)."
  def queues_field, do: "#{ObanPresets}[queues]"

  @doc "Form field name for a single queue's override."
  def queue_field(queue), do: "#{ObanPresets}[queues][#{queue}]"

  @doc "One row per managed queue with its current effective limit (prefill for the advanced editor)."
  def queue_rows do
    effective = ObanPresets.effective_limits()
    Enum.map(ObanPresets.managed_queues(), fn queue -> {queue, Map.get(effective, queue, 1)} end)
  end

  @doc "Layer 2 — one row per federation queue group, with whether it's currently prioritised."
  def group_rows do
    priorities = ObanPresets.current_priorities()

    Enum.map(ObanPresets.queue_groups(), fn {group, meta} ->
      %{
        key: group,
        name: Keyword.get(meta, :name) || Phoenix.Naming.humanize(group),
        description: Keyword.get(meta, :description, ""),
        prioritised: Map.get(priorities, group, false)
      }
    end)
  end

  @doc "Form field name for a group's prioritise toggle."
  def priority_field(group), do: "#{ObanPresets}[prioritised_groups][#{group}]"
end
