defmodule Bonfire.UI.Me.WidgetInstanceFactsLive do
  @moduledoc "The About page's At a glance section: a heading over `Bonfire.UI.Me.InstanceFactsListLive`."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Adds the notes for guests (reading without an account, invite-only signups). By default, when nobody is signed in."
  prop is_guest?, :boolean, default: nil

  @doc "Classes of the block, such as negative margins that take its hairline to a sheet's edges."
  prop class, :css_class, default: nil
end
