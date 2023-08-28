defmodule Bonfire.UI.Me.SettingsViewsLive.AppearanceLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :string
  prop scope, :atom, default: :user

  def render(assigns) do
    scoped = Bonfire.Me.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    assigns
    |> assign(scoped: scoped)
    |> assign(page_title: l("Appearance"))
    |> render_sface()
  end
end
