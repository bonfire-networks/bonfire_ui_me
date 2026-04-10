defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # debug(session, "session")
    page =
      Text.text_only(
        e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction")
      )

    url = Text.text_only(e(params, "url", nil) || e(session, "url", nil))

    go = e(params, "go", nil) || e(params, "go", nil)

    params = Map.put(params, "go", Text.text_only(go || url))

    {:ok,
     socket
     |> assign(:page, page)
     |> assign(:page_title, page)
     |> assign(:canonical_url, url)
     |> assign_global(:go, go)
     |> assign(:name, Text.text_only(e(params, "name", nil) || e(session, "name", nil)))
     |> assign(
       :interaction_type,
       Text.text_only(e(params, "type", nil) || e(session, "type", nil)) || l("follow")
     )
     |> assign(
       :federating?,
       module_enabled?(Bonfire.Federate.ActivityPub) and
         Bonfire.Federate.ActivityPub.federating?()
     )
     |> Bonfire.UI.Me.LoginLive.assign_defaults(params, session)
     |> Bonfire.UI.Me.SignupLive.assign_defaults(params, session, form_key: :signup_form)}
  end

  def generate_url(type, name, url, opts) do
    assigns = assigns(opts)

    go =
      e(assigns, :go, nil) ||
        e(assigns, :__context__, :go, nil) ||
        e(assigns, :__context__, :current_params, "go", nil)

    "/remote_interaction?type=#{type}&name=#{name}&url=#{url}&go=#{go}"
  end
end
