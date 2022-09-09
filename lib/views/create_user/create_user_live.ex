defmodule Bonfire.UI.Me.CreateUserLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  # alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.LivePlugs
  # alias Bonfire.UI.Me.CreateUserLive

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      # LivePlugs.LoadCurrentUser,
      LivePlugs.AccountRequired,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3,
    ]
  end

  defp mounted(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, l("Create a new user profile"))
     |> assign(:page_title, l("Create a new user profile"))
     |> assign_new(:form, fn -> user_form(current_account(socket)) end )
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:without_header, fn -> true end)
     |> assign(:without_sidebar,  true)
      }
  end

  defp user_form(params \\ %{}, account), do: Users.changeset(:create, params, account)

  def handle_event(action, attrs, socket), do: Bonfire.UI.Common.LiveHandlers.handle_event(action, attrs, socket, __MODULE__)
  def handle_info(info, socket), do: Bonfire.UI.Common.LiveHandlers.handle_info(info, socket, __MODULE__)
end
