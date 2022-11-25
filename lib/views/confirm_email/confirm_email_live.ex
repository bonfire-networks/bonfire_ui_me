defmodule Bonfire.UI.Me.ConfirmEmailLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Accounts

  def mount(_params, session, socket) do
    # debug(session)
    {:ok,
     socket
     |> assign(:without_sidebar, true)
     |> assign(:error, session["error"])
     |> assign(:requested, session["requested"])
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_new(:csrf_token, fn -> session["_csrf_token"] end)
     |> assign_new(:form, &form_cs/0)}
  end

  defp form_cs(), do: Accounts.changeset(:confirm_email, %{})
end
