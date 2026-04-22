defmodule Bonfire.UI.Me.ForgotPasswordLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child

  # alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ForgotPasswordController

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(_params, session, socket) do
    passwordless_only? = Bonfire.UI.Me.LoginLive.passwordless_only?()
    page_title = if passwordless_only?, do: l("Sign in"), else: l("Forgot password")

    {:ok,
     socket
     |> assign(:page, page_title)
     |> assign(:page_title, page_title)
     |> assign(:without_sidebar, true)
     |> assign(:no_header, true)
     |> assign(:without_secondary_widgets, true)
     |> assign(:form, session["form"] || ForgotPasswordController.form())
     |> assign(:error, session["error"])
     |> assign(:requested, session["requested"])
     |> assign(:email, session["email"])
     |> assign(:passwordless_only?, passwordless_only?)}
  end
end
