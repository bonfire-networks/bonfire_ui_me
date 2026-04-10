defmodule Bonfire.UI.Me.LoginLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  alias Bonfire.Me.Accounts

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(params, session, socket) do
    {:ok, assign_defaults(socket, params, session)}
  end

  def assign_defaults(socket_or_assigns, params \\ %{}, session \\ %{}) do
    go = e(params, "go", nil) || e(params, :go, nil) || e(session, "go", nil)

    socket_or_assigns
    |> assign(:page, "login")
    |> assign(:page_title, l("Log in"))
    |> assign_new(:go, fn -> go end)
    |> assign_new(:without_sidebar, fn -> true end)
    |> assign_new(:no_header, fn -> true end)
    |> assign_new(:without_secondary_widgets, fn -> true end)
    |> assign_new(:current_account, fn -> nil end)
    |> assign_new(:full_width, fn -> true end)
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

  defp login_form(params) when is_map(params), do: Accounts.changeset(:login, params) |> to_form()
  defp login_form(_), do: login_form(%{})
end
