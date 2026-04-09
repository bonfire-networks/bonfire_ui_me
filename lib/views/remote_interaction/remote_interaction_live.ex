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

    go_after_sign_in = e(params, "go_after_sign_in", nil)

    params = Map.put(params, "go", Text.text_only(go_after_sign_in || url))

    {:ok,
     socket
     |> assign(:page, page)
     |> assign(:page_title, page)
     |> assign(:canonical_url, url)
     |> assign_global(:go_after_sign_in, go_after_sign_in)
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

  def generate_url(type, name, url, context) do
    go_after_sign_in =
      e(context, :go_after_sign_in, nil) || e(context, :__context__, :go_after_sign_in, nil)

    "/remote_interaction?type=#{type}&name=#{name}&url=#{url}&go_after_sign_in=#{go_after_sign_in}"
  end
end
