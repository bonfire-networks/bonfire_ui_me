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
      ],
      settings: [
        sections: [
          profile: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          preferences: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          account: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          shared_user: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          flags: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          ghosted: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          silenced: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          circles: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          roles: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          acls: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          acl: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
          extensions: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive,
        ],
        navigation: Bonfire.UI.Common.SidebarSettingsNavLive.declared_nav()
      ]
  end
end
