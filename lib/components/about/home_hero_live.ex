defmodule Bonfire.UI.Me.HomeHeroLive do
  @moduledoc """
  The guest Home's actions, shown under the shared introduction (`AboutIntroLive`): join or log in (or request an invite on invite-only instances). The community's links and who runs the place are homepage widgets (`Bonfire.UI.Common.WidgetCommunityLinksLive`, `Bonfire.UI.Me.WidgetModsLive`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  def invite_contact?, do: Bonfire.UI.Me.InviteRequestLive.contact?()
end
