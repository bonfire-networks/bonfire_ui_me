defmodule Bonfire.UI.Me.CreateUserTeamLive do
  @moduledoc "Step 2 of creating an organisation profile: optionally invite co-managers. Renders the same `SharedUserLive` invite + roster component the Team Profiles settings tab uses (DRY), for the just-created org (now the current user)."
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {:ok,
     assign(socket,
       selected_tab: "shared_user",
       no_header: true,
       without_sidebar: true,
       without_secondary_widgets: true,
       page: l("Invite your team"),
       page_title: l("Invite your team"),
       current_params: params
     )}
  end
end
