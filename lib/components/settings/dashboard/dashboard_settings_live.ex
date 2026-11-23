defmodule Bonfire.UI.Me.DashboardSettingsLive do
  @moduledoc "Settings for the dashboard's main area: which widgets show and their order, the feed among them (`Bonfire.UI.Common.PlaceWidgetsSettingsLive`), and which feed is the default. A user's own, or with `scope: :instance` the defaults for everyone who hasn't set theirs."
  use Bonfire.UI.Common.Web, :stateful_component

  prop scope, :any, default: nil

  data feed_available, :boolean, default: false

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     assign(socket,
       feed_available:
         not is_nil(current_user(socket)) and module_enabled?(Bonfire.UI.Social.FeedLive, socket)
     )}
  end
end
