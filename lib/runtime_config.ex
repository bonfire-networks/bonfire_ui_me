defmodule Bonfire.UI.Me.RuntimeConfig do
  use Bonfire.Common.Localise

  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @doc """
  NOTE: you can override this default config in your app's `runtime.exs`, by placing similarly-named config keys below the `Bonfire.Common.Config.LoadExtensionsConfig.load_configs()` line
  """
  def config do
    import Config

    # config :bonfire_ui_me,
    #   modularity: :disabled

    # One getting-started step, declared here because it is about this extension's feature: the widget that shows it holds no steps of its own, and the list merges across extensions. The copy is compiled here so `mix gettext.extract` sees it, and the detector is this extension's own function.
    config :bonfire_ui_common, Bonfire.UI.Common.WidgetGettingStartedLive,
      actions_registry: [
        profile: %{
          title: l("Add a profile picture and bio"),
          rationale: l("Letting people see who you are makes following you a real choice."),
          cta_label: l("Edit your profile"),
          cta_path: "/settings/",
          needs: Bonfire.Me.Users,
          done?: &Bonfire.UI.Me.RuntimeConfig.profile_complete?/1
        }
      ]

    config :bonfire, :ui,
      profile: [
        navigation: [
          timeline: l("Timeline")
        ],
        sections: [
          # nil: Bonfire.UI.Me.ProfileInfoLive,
          # about: Bonfire.UI.Me.ProfileInfoLive,
          follow: Bonfire.UI.Me.RemoteInteractionFormLive,
          # `/@username/interact/:type` deeplinks (block/flag/…) render the same remote-interaction
          # form as `follow`; the type comes from the `:extra` path segment (see ProfileLive)
          interact: Bonfire.UI.Me.RemoteInteractionFormLive
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
          extensions: Bonfire.UI.Me.SettingsViewsLive.PreferencesLive
        ],
        navigation: Bonfire.UI.Me.SidebarSettingsNavLive.declared_nav()
      ],
      activity_preview: [],
      object_preview: [
        {Bonfire.Data.Identity.User, Bonfire.UI.Me.Preview.CharacterLive},
        {Bonfire.Data.Social.Follow, Bonfire.UI.Me.Preview.CharacterLive}
      ]
  end

  @doc """
  Whether somebody has both a picture and something written about themselves.

  Beside the step that asks for it, since what counts as a filled-in profile is this extension's business. Read from the loaded user, so it costs nothing.
  """
  def profile_complete?(nil), do: false

  def profile_complete?(user) do
    summary = Bonfire.Common.E.ed(user, :profile, :summary, "")

    has_avatar? =
      not is_nil(Bonfire.Common.E.ed(user, :profile, :icon_id, nil)) or
        not is_nil(Bonfire.Common.E.ed(user, :profile, :icon, :id, nil)) or
        not is_nil(Bonfire.Common.E.ed(user, :profile, :icon, :url, nil))

    has_avatar? and is_binary(summary) and String.trim(summary) != ""
  end
end
