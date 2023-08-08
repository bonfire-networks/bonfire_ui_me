defmodule Bonfire.UI.Me.LoginLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Accounts

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(params, session, socket) do
    {:ok,
     assign_defaults(params, session, socket)}
  end

  def assign_defaults(params \\ %{}, session \\ %{}, socket_or_assigns) do
    socket_or_assigns
    |> assign(:page, "login")
     |> assign(:page_title, l("Log in"))
     |> assign_new(:without_sidebar, fn -> true end)
     |> assign_new(:without_widgets, fn -> true end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_global(:csrf_token, session["_csrf_token"])
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:feed_title, fn -> "Public Feed" end)
     |> assign_new(:form, fn -> login_form(params) end)
     |> assign_new(:conn, fn -> session["conn"] end)
  end

  def custom_render(socket_or_assigns \\ %{}) do
     assign_defaults(socket_or_assigns)
     |> render()
  end

  defp login_form(params), do: Accounts.changeset(:login, params)
end
