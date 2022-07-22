defmodule Bonfire.UI.Me.UsersDirectoryLive do
  use Bonfire.UI.Common.Web, :surface_view
  alias Bonfire.UI.Me.LivePlugs
  import Bonfire.UI.Me.Integration

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.AccountRequired,
      # LivePlugs.LoadCurrentUserCircles,
      # LivePlugs.LoadCurrentAccountUsers,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  defp mounted(_params, _session, socket) do
    current_user = current_user(socket)
    show_to = Bonfire.Me.Settings.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to], :users)

    if show_to || is_admin?(current_user) do
      if show_to==:guests or current_user(socket) || current_account(socket) do

        users = Bonfire.Me.Users.list(current_user)

        {:ok,
          socket
          |> assign(
            page_title: "Users directory",
            page: "Users",
            search_placeholder: "Search in users directory",
            users: users
          )}
      else
        error("You need to log in before browsing the directory")
      end
    else
      error("User discoverability is disabled on this instance")
    end
  end

end
