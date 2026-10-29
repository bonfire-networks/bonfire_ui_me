defmodule Bonfire.UI.Me.Dashboard do
  @moduledoc """
  The dashboard's main-area widgets and feed, shared by each flavour's `DashboardLive` and `Bonfire.UI.Me.DashboardSettingsLive`.

  A flavour picks widgets from `catalogue/0` via its `main_widget_choices/0`. Users show/hide them (`[DashboardLive, :include, key]`), order them (`[:ui, :widget_order, :dashboard_main_widgets]`) and can add their feed at the end (`[DashboardLive, :include, :feed]`).
  """
  use Bonfire.Common.Utils

  alias Bonfire.Common.Settings
  alias Bonfire.UI.Common.WidgetsLive

  @settings_key Bonfire.Web.Views.DashboardLive
  # the id of the dashboard's main `WidgetsLive`
  @order_key :dashboard_main_widgets

  @doc "Used when a flavour's dashboard doesn't define `main_widget_choices/0`."
  def default_choices,
    do: [:instance_pinned, :trending_discussions, :polls_closing_soon, :suggested_profiles]

  @doc "Every widget the main area can have. Styling comes from `[data-id=\"dashboard_main\"]` in interface.css."
  def catalogue do
    [
      %{
        key: :instance_pinned,
        name: l("Spotlight"),
        guests: true,
        widget: %{
          module: Bonfire.UI.Reactions.PinnedCarouselLive,
          data: [title: l("Spotlight")],
          type: Surface.LiveComponent
        }
      },
      %{
        key: :popular_discussions,
        name: l("Popular discussions"),
        guests: true,
        widget: %{
          module: Bonfire.UI.Social.WidgetDiscussionsLive,
          data: [widget_title: l("Popular discussions")],
          type: Surface.Component
        }
      },
      %{
        key: :trending_discussions,
        name: l("Top discussions"),
        widget: %{
          module: Bonfire.UI.Social.WidgetTrendingDiscussionsLive,
          # no `widget_title` here: a title passed in beats the widget's own, which follows the vocabulary preset the instance or the user chose
          data: [limit: 5],
          type: Surface.Component
        }
      },
      %{
        key: :polls_closing_soon,
        name: l("Polls closing soon"),
        widget: %{
          module: Bonfire.Poll.Web.WidgetPollsClosingSoonLive,
          data: [limit: 3, widget_title: l("Polls closing soon")],
          type: Surface.Component
        }
      },
      %{
        key: :suggested_profiles,
        name: l("Who to follow"),
        widget: %{
          module: Bonfire.UI.Social.WidgetSuggestedProfilesLive,
          data: [widget_title: l("Who to follow")],
          type: Surface.Component
        }
      }
    ]
  end

  @doc "The catalogue entries for `choices`, minus disabled extensions and (for guests) signed-in-only widgets."
  def options(choices, context) do
    by_key = Map.new(catalogue(), &{&1.key, &1})

    choices
    |> Enum.flat_map(&List.wrap(by_key[&1]))
    |> Enum.filter(fn option ->
      (option[:guests] || current_user(context)) &&
        Bonfire.Common.Extend.module_enabled?(option.widget.module, context)
    end)
  end

  @doc "`options/2` in the user's saved order."
  def ordered_options(choices, context) do
    order =
      Settings.get([:ui, :widget_order, @order_key], %{}, current_user: current_user(context))

    choices
    |> options(context)
    |> WidgetsLive.sort_by_saved_order(order, &WidgetsLive.order_key(&1.widget))
    |> Enum.map(&elem(&1, 0))
  end

  @doc "The widgets the user hasn't hidden, for the dashboard's `WidgetsLive`."
  def main_widgets(choices, current_user) do
    for option <- options(choices, current_user),
        Settings.get([@settings_key, :include, option.key], true, current_user: current_user) !=
          false,
        do: option.widget
  end

  @doc "Saves the order of all offered widgets, hidden ones included so they keep their place."
  def save_order(options_in_order, current_user) do
    Bonfire.Common.Settings.LiveHandler.save_widget_order(
      @order_key,
      Enum.map(options_in_order, &WidgetsLive.order_key(&1.widget)),
      current_user: current_user
    )
  end

  @doc "Whether the user has the feed at the end of their dashboard."
  def show_feed?(current_user) do
    not is_nil(current_user) and
      Settings.get([@settings_key, :include, :feed], feed_default(current_user),
        current_user: current_user
      ) == true
  end

  @doc "On for users of the old feed-only mode (`[DashboardLive, :default_feed]`), which this replaces."
  def feed_default(current_user) do
    Settings.get([@settings_key, :default_feed], false, current_user: current_user) in [:my, true]
  end

  @doc "`{feed_props, component_id}` for the `requested` feed slug, else the user's default feed, or `{nil, nil}` when it's off."
  def feed_assigns(socket, requested \\ nil) do
    current_user = current_user(socket)

    # loaded once, also for the tabs
    presets =
      maybe_apply(Bonfire.UI.Social.FeedNavigation, :list_presets, [[current_user: current_user]],
        fallback_return: []
      )

    with true <- show_feed?(current_user),
         [_ | _] = feed_assigns <-
           Bonfire.Common.Utils.maybe_apply(
             Bonfire.Social.Feeds.LiveHandler,
             :feed_default_assigns,
             [feed_name(presets, current_user, requested) |> with_filters(), socket],
             fallback_return: nil
           ) do
      # always start from the newest activities, not the preset's saved reading position
      feed_assigns =
        feed_assigns
        |> Keyword.put(:disable_marker, true)
        |> Keyword.put(:nav_presets, presets)

      {Keyword.delete(feed_assigns, :feed_component_id), feed_assigns[:feed_component_id]}
    else
      _ -> {nil, nil}
    end
  end

  # the requested feed if permitted, else the default feed
  defp feed_name(presets, current_user, requested) do
    # matched against permitted slugs: never an atom from the URL
    requested =
      requested &&
        Enum.find_value(presets, fn {slug, _} -> to_string(slug) == requested && slug end)

    requested ||
      Bonfire.Common.Utils.maybe_apply(
        Bonfire.UI.Social.FeedNavigation,
        :default_feed,
        [presets, [current_user: current_user]],
        fallback_return: nil
      ) || :default
  end

  # string (custom) feed names only resolve as presets with filters, as on `/feed/<name>`
  defp with_filters(name) when is_binary(name), do: {name, %{}}
  defp with_filters(name), do: name
end
