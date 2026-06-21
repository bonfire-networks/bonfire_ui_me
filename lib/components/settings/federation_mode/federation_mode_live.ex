defmodule Bonfire.UI.Me.SettingsViewsLive.FederationModeLive do
  @moduledoc """
  Shared federation-mode selector (rich radio cards) used by both the instance
  configuration page (`scope: :instance`) and the per-user/account safety page
  (`scope: :user | :account`).

  The selected card is owned by the native radios + `peer-checked`/`has-[:checked]`
  CSS, so clicking highlights instantly; `phx-change` persists it; and `checked`
  (seeded from the *computed* `federation_mode/1`, the same source the sidebar uses)
  matches the saved mode on load/reload. The card grid is `phx-update="ignore"` so the
  post-save re-render doesn't reset the user's selection. See bonfire-app#2056.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  # which settings scope this selector writes to: :instance | :user | :account
  prop scope, :atom, default: :user

  @doc """
  The currently-effective federation mode, as a radio `value` string, for seeding the
  initial `checked` radio. Reads via the canonical
  `Bonfire.Federate.ActivityPub.federation_mode/1` — the SAME source the sidebar
  (`ImpressumLive`) uses — so the highlight matches the sidebar on load/reload.
  """
  def current_federation_mode(context) do
    case maybe_apply(
           Bonfire.Federate.ActivityPub,
           :federation_mode,
           current_user(context),
           fallback_return: true
         ) do
      # `federation_mode/1` returns nil for manual/paused mode (`to_string(nil)` is "")
      nil -> "manual"
      mode -> to_string(mode)
    end
  end

  # Layer 1 presets for the federation choice (intent-named, with a plain-language
  # description and an icon). See `.claude/DESIGN.md`.
  def federation_modes do
    [
      %{
        value: "true",
        name: l("Open"),
        tag: l("Automatic federation"),
        icon: "ph:globe-hemisphere-west-duotone",
        description:
          l(
            "Push activities to the fediverse, and accept activities from anyone that isn't blocked."
          )
      },
      %{
        value: "allowlist_only",
        name: l("Archipelago"),
        tag: l("Allow-list only"),
        icon: "ph:list-checks-duotone",
        description: l("Federate only with instances and people that are explicitly allowed.")
      },
      %{
        value: "manual",
        name: l("Manual"),
        tag: l("On-demand federation"),
        icon: "ph:cursor-click-duotone",
        description:
          l(
            "Nothing is pushed automatically. People can still look up and fetch individual profiles and posts on demand."
          )
      },
      %{
        value: "false",
        name: l("Disabled"),
        tag: l("No federation"),
        icon: "ph:plugs-duotone",
        description:
          l("Turn federation off entirely, keeping this instance isolated from the fediverse.")
      }
    ]
  end

  @doc """
  The cards offered for the given scope. The instance scope offers all four; a
  user/account scope is constrained by the instance's own mode (e.g. you can't choose
  "Open" if the instance is allowlist-only or manual).
  """
  def federation_modes(:instance), do: federation_modes()

  def federation_modes(_user_or_account) do
    allowed = allowed_user_mode_values()
    Enum.filter(federation_modes(), &(&1.value in allowed))
  end

  # A user can only pick a mode at least as restrictive as the instance's own mode.
  # Derived from the canonical `federation_mode/0` (instance mode) — the same source the
  # highlight uses — so it stays consistent and is exercisable in tests.
  defp allowed_user_mode_values do
    case maybe_apply(Bonfire.Federate.ActivityPub, :federation_mode, [], fallback_return: true) do
      # instance disabled — user can only stay disabled
      false -> ["false"]
      # instance manual — user can't enable, only stay manual or disable
      nil -> ["manual", "false"]
      # instance allowlist-only — user can't choose fully Open
      :allowlist_only -> ["allowlist_only", "manual", "false"]
      # instance open — user may pick any mode
      _ -> ["true", "allowlist_only", "manual", "false"]
    end
  end

  @doc "The form field name to write for this scope."
  def field_name(:instance), do: "activity_pub[instance][federating]"
  def field_name(_user_or_account), do: "activity_pub[user_federating]"

  @doc "The `data-scope` for the wrapping form (kept stable per scope for tests)."
  def form_data_scope(:instance), do: "set_federation"
  def form_data_scope(_user_or_account), do: "federation_mode"

  @doc "Where the allowlist-management link points, and its label, for this scope."
  def allowlist_link(:instance),
    do: {~p"/settings/instance/remote_allow_list", l("Manage allowlist")}

  def allowlist_link(_user_or_account),
    do: {~p"/allowlisted", l("Manage my federation allowlist")}
end
