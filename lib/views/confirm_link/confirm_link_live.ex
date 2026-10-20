defmodule Bonfire.UI.Me.ConfirmLinkLive do
  @moduledoc "The page an emailed link (signup confirmation, magic-link sign-in, password reset) opens. Only the button on it, which posts to `action`, uses the link's token up. Mail scanners open links without pressing buttons, so they can't use the token up before the person does. See `Bonfire.UI.Me.EmailLink`."
  use Bonfire.UI.Common.Web, :surface_live_view_child

  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:without_sidebar, true)
     |> assign(:no_header, true)
     |> assign(:hide_mobile_dock, true)
     |> assign(:without_secondary_widgets, true)
     |> assign(:title, session["title"])
     |> assign(:intro, session["intro"])
     |> assign(:button, session["button"])
     |> assign(:action, session["action"])
     |> assign_new(:current_account, fn -> nil end)
     |> assign_new(:current_account_id, fn -> nil end)
     |> assign_new(:current_user, fn -> nil end)
     |> assign_new(:current_user_id, fn -> nil end)
     |> assign_global(:csrf_token, session["_csrf_token"])}
  end
end
