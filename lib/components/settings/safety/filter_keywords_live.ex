defmodule Bonfire.UI.Me.SettingsViewsLive.FilterKeywordsLive do
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Common.Settings

  @doc """
  Component for managing keyword filters that hide matching content from feeds.
  """
  prop filter_keywords, :list, required: true
  prop scope, :any, required: true

  def handle_event("add_keyword", %{"keyword" => raw}, socket) do
    new_keywords =
      raw
      |> String.split(~r/[,\n]+/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if new_keywords == [] do
      {:noreply, socket}
    else
      updated =
        (socket.assigns.filter_keywords ++ new_keywords)
        |> Enum.uniq()

      save_and_update(socket, updated)
    end
  end

  def handle_event("remove_keyword", %{"index" => idx}, socket) do
    idx = String.to_integer(idx)
    updated = List.delete_at(socket.assigns.filter_keywords, idx)
    save_and_update(socket, updated)
  end

  defp save_and_update(socket, keywords) do
    Settings.put([:bonfire_boundaries, :filter_keywords], keywords,
      scope: e(assigns(socket), :scope, nil),
      current_user: current_user(socket)
    )

    {:noreply, assign(socket, filter_keywords: keywords)}
  end
end
