defmodule Bonfire.UI.Me.ConfirmEmailLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  alias Bonfire.Me.Accounts

  def mount(_params, session, socket) do
    # debug(session)
    {:ok,
     socket
     |> assign(:without_sidebar, true)
     |> assign(:without_secondary_widgets, true)
     |> assign(:error, session["error"])
     |> assign(:requested, session["requested"])
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_global(:csrf_token, session["_csrf_token"])
     |> assign_new(:form, &form_cs/0)}
  end

  defp form_cs(), do: Accounts.changeset(:confirm_email, %{})
end
