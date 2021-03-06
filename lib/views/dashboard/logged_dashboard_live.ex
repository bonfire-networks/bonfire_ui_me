defmodule Bonfire.UI.Me.LoggedDashboardLive do
  @deprecated
  use Bonfire.UI.Common.Web, :surface_view
  alias Bonfire.UI.Me.LivePlugs

    def mount(params, session, socket) do
      live_plug params, session, socket, [
        LivePlugs.LoadCurrentAccount,
        LivePlugs.LoadCurrentUser,
        LivePlugs.AccountRequired,
        LivePlugs.LoadCurrentAccountUsers,
        # LivePlugs.LoadCurrentUserCircles,
        Bonfire.UI.Common.LivePlugs.StaticChanged,
        Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
        &mounted/3,
      ]
    end

    defp mounted(_params, _session, socket) do

      {:ok, socket
      |> assign(
        page: "dashboard",
        smart_input: true,
        page_title: l("Bonfire Dashboard"),
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

    defdelegate handle_params(params, attrs, socket), to: Bonfire.UI.Common.LiveHandlers
    def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
    def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)

  end
