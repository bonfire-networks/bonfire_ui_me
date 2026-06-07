defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceConfigLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :any

  prop uploads, :any,
    default: %{
      icon: %Phoenix.LiveView.UploadConfig{ref: "a1"},
      image: %Phoenix.LiveView.UploadConfig{ref: "a2"}
    }

  @doc """
  The currently-saved instance federation mode, as a string, for seeding the
  initial `checked` radio. Read the same way the other settings inputs do (via
  `SettingsSelectLive`'s loader), so it's correct on load/reload. After that the
  native radio owns the selection (the options grid is `phx-update="ignore"`).
  """
  def current_federation_mode(context) do
    Bonfire.Common.Settings.__get__(
      [:activity_pub, :instance, :federating],
      true,
      Bonfire.Common.Settings.LiveHandler.scoped(:instance, context)
    )
    |> to_string()
  end

  # Layer 1 presets for the instance federation choice (intent-named, with a
  # plain-language description and an icon). See `.claude/DESIGN.md`.
  def federation_modes do
    [
      %{
        value: "true",
        name: l("Open"),
        tag: l("Automatic"),
        icon: "ph:globe-hemisphere-west-duotone",
        description:
          l(
            "Push your public activity to the fediverse, and accept activity from anyone you haven't blocked."
          )
      },
      %{
        value: "allowlist_only",
        name: l("Allowlist only"),
        tag: l("Archipelago"),
        icon: "ph:list-checks-duotone",
        description:
          l(
            "Federate only with the instances and people you've explicitly added to your allowlist."
          )
      },
      %{
        value: "manual",
        name: l("Manual"),
        tag: nil,
        icon: "ph:cursor-click-duotone",
        description:
          l(
            "Nothing is pushed out automatically. People here can still look up and fetch individual profiles and posts on demand."
          )
      },
      %{
        value: "false",
        name: l("Disabled"),
        tag: nil,
        icon: "ph:plugs-duotone",
        description:
          l("Turn federation off entirely, keeping this instance fully isolated from the fediverse.")
      }
    ]
  end
end
