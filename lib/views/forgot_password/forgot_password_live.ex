defmodule Bonfire.UI.Me.ForgotPasswordLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  # alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ForgotPasswordController

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page, l("Forgot password"))
     |> assign(:page_title, l("Forgot password"))
     |> assign(:without_sidebar, true)
     |> assign(:without_secondary_widgets, true)
     |> assign(:form, ForgotPasswordController.form())
     |> assign(:error, session["error"])
     |> assign(:requested, session["requested"])}
  end
end
