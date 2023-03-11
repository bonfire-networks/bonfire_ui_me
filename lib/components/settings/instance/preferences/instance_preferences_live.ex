defmodule Bonfire.UI.Me.SettingsViewsLive.InstancePreferencesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string

  prop uploads, :any,
    default: %{
      icon: %Phoenix.LiveView.UploadConfig{ref: "a1"},
      image: %Phoenix.LiveView.UploadConfig{ref: "a2"}
    }
end
