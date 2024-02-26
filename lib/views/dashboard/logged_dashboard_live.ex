defmodule Bonfire.UI.Me.LoggedDashboardLive do
  @moduledoc deprecated: "Dashboard is bonfire_spark extension instead"
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs,
            [
              Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
              Bonfire.UI.Me.LivePlugs.AccountRequired,
              LivePlugs.LoadCurrentAccountUsers
            ]}

  def mount(_params, _session, socket) do
    {
      :ok,
      assign(
        socket,
        page: "dashboard",
        smart_input: true,
        page_title: l("Dashboard"),
        feed_title: l("My feed"),
        selected_tab: "feed",
        go: "",
        without_sidebar: true
      )

      # |> assign_global(to_circles: Bonfire.Boundaries.Circles.list_my_defaults(socket))
    }
  end

  # def handle_params(%{"tab" => tab} = _params, _url, socket) do
  #   {:noreply,
  #    assign(socket,
  #      selected_tab: tab
  #    )}
  # end
end
