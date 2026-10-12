defmodule Bonfire.UI.Me.DashboardSettingsLive do
  @moduledoc "User settings for the dashboard's main area: which widgets show, their order, and the feed. See `Bonfire.UI.Me.Dashboard`."
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.UI.Me.Dashboard

  prop scope, :any, default: nil

  data widgets, :list, default: []
  data feed_available, :boolean, default: false

  data feed_default, :boolean, default: false

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    user = current_user(socket)

    {:ok,
     assign(socket,
       widgets: Dashboard.ordered_options(choices(), user),
       feed_available: not is_nil(user) and module_enabled?(Bonfire.UI.Social.FeedLive, socket),
       feed_default: Dashboard.feed_default(user)
     )}
  end

  # DashboardLive lives in the main app, which compiles after this extension
  defp choices do
    Bonfire.Common.Utils.maybe_apply(Bonfire.Web.Views.DashboardLive, :main_widget_choices, [],
      fallback_return: Dashboard.default_choices()
    )
  end

  def handle_event("move", %{"key" => key, "direction" => direction}, socket) do
    widgets = socket.assigns.widgets

    with index when is_integer(index) <- Enum.find_index(widgets, &(to_string(&1.key) == key)),
         to = if(direction == "up", do: index - 1, else: index + 1),
         true <- to in 0..(length(widgets) - 1)//1,
         widgets = Enum.slide(widgets, index, to),
         {:ok, settings} <- Dashboard.save_order(widgets, current_user(socket)) do
      {:noreply, socket |> assign(:widgets, widgets) |> maybe_assign_context(settings)}
    else
      {:error, _} = failed ->
        error(failed, "Could not save the dashboard widget order")

        {:noreply,
         assign_flash(socket, :error, l("Could not save the new order. Please try again."))}

      _ ->
        {:noreply, socket}
    end
  end
end
