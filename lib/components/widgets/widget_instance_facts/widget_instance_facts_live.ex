defmodule Bonfire.UI.Me.WidgetInstanceFactsLive do
  @moduledoc "The facts people compare servers on (federation, discoverability, and for guests: reading without an account, invite-only signups). A widget on the guest homepage, also shown on About."
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget(l("At a glance"), id: :instance_facts, skeleton: :stats)

  @doc "Adds the notes for guests (reading without an account, invite-only signups). By default, when nobody is signed in."
  prop is_guest?, :boolean, default: nil

  @doc "Classes of the block, such as negative margins that take its hairline to a sheet's edges."
  prop class, :css_class, default: nil
end
