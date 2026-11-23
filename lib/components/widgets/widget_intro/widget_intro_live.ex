defmodule Bonfire.UI.Me.WidgetIntroLive do
  @moduledoc "The community's introduction (`AboutIntroLive`: its name, tagline and welcome text) with the guest homepage's actions (`HomeHeroLive`: join, sign in, request an invite). A widget on the guest homepage; About shows `AboutIntroLive` itself."
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget(l("Introduction"), id: :intro, width: :wide)
end
