defmodule Bonfire.UI.Me.DashboardMainLive do
  @moduledoc "The dashboard's main area: the place `{DashboardLive, :main}`, its widgets (see `Bonfire.UI.Common.Widgets.for_place/2`), the feed among them (`Bonfire.UI.Social.WidgetFeedLive`)."
  use Bonfire.UI.Common.Web, :stateless_component

  prop widgets, :list, default: []

  @doc "The feed asked for with `?feed=`, for the feed widget's tabs."
  prop requested_feed, :string, default: nil

  prop page, :string, default: nil
  prop selected_tab, :any, default: nil

  @doc "Where a feed tab links: the dashboard, with that feed."
  def feed_tab_path(slug), do: "/dashboard?feed=#{URI.encode_www_form(to_string(slug))}"
end
