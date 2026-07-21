defmodule Bonfire.UI.Me.ChangePasswordLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  alias Bonfire.UI.Me.ChangePasswordController
  # alias Bonfire.Me.Accounts

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, l("Change my password"))
     |> assign(:without_sidebar, true)
     |> assign(:no_header, true)
     |> assign(:without_secondary_widgets, true)
     |> assign(:form, session["form"])
     |> assign(:error, session["error"])
     |> assign_new(:resetting_password, fn ->
       session["resetting_password"] ||
         not Bonfire.Me.Accounts.account_has_password?(current_account(socket))
     end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:form, &ChangePasswordController.form_cs/0)}
  end
end
