defmodule Bonfire.UI.Me.ChangeEmailLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  alias Bonfire.UI.Me.ChangeEmailController
  # alias Bonfire.Me.Accounts

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, l("Change my email"))
     |> assign(:without_sidebar, true)
     |> assign(:without_widget, true)
     |> assign(:form, session["form"])
     |> assign(:error, session["error"])
     #  |> assign(:resetting_password, session["resetting_password"])
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:form, &ChangeEmailController.form_cs/0)}
  end
end
