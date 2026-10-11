defmodule Bonfire.UI.Me.DashboardMainLive do
  @moduledoc "The dashboard's main area: the user's widgets, then their feed (always last). See `Bonfire.UI.Me.Dashboard`."
  use Bonfire.UI.Common.Web, :stateless_component

  prop widgets, :list, default: []

  prop feed, :any, default: nil
  prop feed_id, :any, default: nil

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil
end
