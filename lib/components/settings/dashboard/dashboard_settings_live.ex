defmodule Bonfire.UI.Me.DashboardSettingsLive do
  @moduledoc "Settings for the dashboard's main area: which widgets show and their order, the feed among them (`Bonfire.UI.Common.PlaceWidgetsSettingsLive`), and which feed is the default. A user's own, or with `scope: :instance` the defaults for everyone who hasn't set theirs."
  use Bonfire.UI.Common.Web, :stateful_component

  prop scope, :any, default: nil

  data feed_available, :boolean, default: false
  data circle_available, :boolean, default: false

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    signed_in? = not is_nil(current_user(socket))

    {:ok,
     assign(socket,
       feed_available: signed_in? and module_enabled?(Bonfire.UI.Social.FeedLive, socket),
       circle_available:
         signed_in? and
           module_enabled?(Bonfire.UI.Boundaries.WidgetCircleMembersLive, socket)
     )}
  end
end
