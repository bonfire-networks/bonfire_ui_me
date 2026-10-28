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
     |> assign(:hide_mobile_dock, true)
     |> assign(:without_secondary_widgets, true)
     |> assign(:form, session["form"] || ForgotPasswordController.form())
     |> assign(:error, session["error"])
     |> assign(:requested, session["requested"])
     |> assign(:email, session["email"])
     |> assign(:go, session["go"])
     |> assign(:passwordless_only?, passwordless_only?)
     # show the domain-restriction hint only when signups are limited AND the visitor has no invite
     # (an invite bypasses the restriction, so the hint would be wrong for them)
     |> assign(
       :show_domain_hint,
       Bonfire.Me.Accounts.signup_domain_gate_active?() and is_nil(session["invite"])
     )}
  end

  @doc """
  The heading, which changes once the email is sent.

      iex> Bonfire.UI.Me.ForgotPasswordLive.title(true, false)
      "Check your inbox"

      iex> Bonfire.UI.Me.ForgotPasswordLive.title(nil, true)
      "Sign in"

      iex> Bonfire.UI.Me.ForgotPasswordLive.title(nil, false)
      "Forgot your password?"
  """
  def title(requested, passwordless_only?)
  def title(requested, _) when requested not in [nil, false], do: l("Check your inbox")
  def title(_, true), do: l("Sign in")
  def title(_, _), do: l("Forgot your password?")
end
