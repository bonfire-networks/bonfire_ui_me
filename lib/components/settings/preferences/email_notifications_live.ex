defmodule Bonfire.Me.Social.Settings.EmailNotificationsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string
  prop scope, :any, default: nil
  prop feed_name, :any, default: nil
  prop event_name, :any, default: nil
  prop event_target, :any, default: nil
  prop hide_forced_defaults, :boolean, default: false

  # declare_settings_component(l("What email notifications to receive"), icon: "fluent:people-team-16-filled")
end
