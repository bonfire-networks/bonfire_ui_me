defmodule Bonfire.UI.Me.SignupLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  # alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.SignupController

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(_params, session, socket) do
    # debug(session, "session")
    {:ok,
     socket
     |> assign_global(:current_url, "/signup")
     |> assign(:page, l("signup"))
     |> assign(:page_title, l("Sign up"))
     |> assign_new(:no_header, fn -> true end)
     |> assign(:invite, e(session, "invite", nil))
     |> assign(:registered, e(session, "registered", nil))
     |> assign_new(:without_sidebar, fn -> true end)
     |> assign_new(:without_secondary_widgets, fn -> true end)
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_new(:open_id_provider, fn -> session["open_id_provider"] end)
     |> assign_global(:csrf_token, session["_csrf_token"])
     |> assign_new(:error, fn -> nil end)
     |> assign_new(:form, fn -> SignupController.form_cs(session) end)
     |> assign_new(:auth_second_factor_secret, fn ->
       session["auth_second_factor_secret"]
     end)}
  end
end
