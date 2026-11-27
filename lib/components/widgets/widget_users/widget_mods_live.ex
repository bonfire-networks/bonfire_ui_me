defmodule Bonfire.UI.Me.WidgetModsLive do
  @moduledoc """
  The instance's moderators, with a button to message them all. Renders nothing when there are none to show.

  In a main area (`showing_within: :main`, eg. the guest homepage and About) as a grid of profile cards; in a sidebar as a compact list.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  declare_widget(l("Moderators"), id: :mods, skeleton: :people)

  prop widget_title, :string, default: nil
  prop showing_within, :atom, default: :sidebar

  @doc "Classes of the grid's block, such as negative margins that take its hairline to a sheet's edges."
  prop class, :css_class, default: nil

  def handle_event("reset", _, socket) do
    Bonfire.Me.Users.list_declared_moderators(cache: :reset)

    {:noreply,
     socket
     #  TODO: how to update them without reloading or making this a stateful component
     |> assign_flash(
       :info,
       l("Moderators have been refreshed.") <>
         " " <> l("You need to reload to see updates, if any.")
     )}
  end
end
