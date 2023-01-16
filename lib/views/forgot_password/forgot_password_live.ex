defmodule Bonfire.UI.Me.ForgotPasswordLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.UI.Me.LivePlugs
  # alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ForgotPasswordController

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

  defp mounted(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page, l("Forgot password"))
     |> assign(:page_title, l("Forgot password"))
     |> assign(:without_sidebar, true)
     |> assign(:without_widgets, true)
     |> assign(:form, ForgotPasswordController.form())
     |> assign(:error, session["error"])
     |> assign(:requested, session["requested"])}
  end
end
