defmodule Bonfire.UI.Me.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @doc """
  NOTE: you can override this default config in your app's `runtime.exs`, by placing similarly-named config keys below the `Bonfire.Common.Config.LoadExtensionsConfig.load_configs()` line
  """
  def config do
    import Config

    config :bonfire_ui_me,
      disabled: false

    config :bonfire, :ui,
      profile: [
        # TODO: make dynamic based on active extensions
        sections: [
          follow: Bonfire.UI.Me.RemoteInteractionFormLive
        ],
        widgets: []
      ]
  end
end
