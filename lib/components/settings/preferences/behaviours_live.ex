defmodule Bonfire.UI.Me.SettingsViewsLive.BehavioursLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop selected_tab, :any
  prop scope, :atom, default: nil

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      assigns
      |> assign(scoped: scoped)
      |> assign(page_title: l("Preferences"))
      |> render_sface()
    end
  end
end
