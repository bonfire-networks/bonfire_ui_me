defmodule Bonfire.UI.Me.SettingsViewsLive.PreferencesLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop scope, :atom, default: :user

  def render(assigns) do
    scoped = Bonfire.Me.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    assigns
    |> assign(scoped: scoped)
    |> render_sface()
  end
end
