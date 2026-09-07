defmodule Bonfire.UI.Me.AccountVerificationViewLive do
  @moduledoc "Verification presentation. All state-changing submissions go through the controller and session."
  use Bonfire.UI.Common.Web, :surface_live_view_child

  @impl true
  def mount(_params, session, socket) do
    {:ok, assign(socket,
      page_title: l("Account verification"), no_header: true,
      without_sidebar: true, without_secondary_widgets: true, hide_mobile_dock: true,
      state: session["state"], description: session["description"],
      pending_id: session["id"], action: session["action"],
      email: session["email"], has_password: session["has_password"], error: session["error"],
      form: to_form(%{}, as: :verification))}
  end
end
