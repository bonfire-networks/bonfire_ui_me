defmodule Bonfire.UI.Me.CreateUserLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  # alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users

  # alias Bonfire.UI.Me.CreateUserLive

  on_mount {LivePlugs,
            [Bonfire.UI.Me.LivePlugs.LoadCurrentUser, Bonfire.UI.Me.LivePlugs.AccountRequired]}

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, l("Create a new user profile"))
     |> assign(:page_title, l("Create a new user profile"))
     |> assign_new(:form, fn -> user_form(current_account(socket)) end)
     |> assign_new(:error, fn -> nil end)
     |> assign(
       without_sidebar: true,
       no_header: true,
       without_secondary_widgets: true,
       smart_input_opts: %{hide_buttons: true}
     )}
  end

  defp user_form(params \\ %{}, account),
    do: Users.changeset(:create, params, account)
end
