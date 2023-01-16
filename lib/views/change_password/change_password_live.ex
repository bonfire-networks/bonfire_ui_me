defmodule Bonfire.UI.Me.ChangePasswordLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs
  alias Bonfire.UI.Me.ChangePasswordController
  alias Bonfire.Me.Accounts

  def mount(params, session, socket) do
    live_plug(params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ])
  end

  def mounted(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, l("Change my password"))
     |> assign(:without_sidebar, true)
     |> assign(:without_widgets, true)
     |> assign(:form, session["form"])
     |> assign(:error, session["error"])
     |> assign(:resetting_password, session["resetting_password"])
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:form, &ChangePasswordController.form_cs/0)}
  end
end
