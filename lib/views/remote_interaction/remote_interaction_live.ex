defmodule Bonfire.UI.Me.RemoteInteractionLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, session, socket) do
    # debug(session, "session")
    page =
      Text.text_only(
        e(params, "page", "Remote interaction") || e(session, "page", "Remote interaction")
      )

    url =
      case e(params, "media_uri", nil) do
        # from the comments embed of a page with no thread yet: start it, as signing in would
        media_uri when is_binary(media_uri) -> page_post_ap_id(media_uri, params, socket)
        _ -> nil
      end ||
        Text.text_only(e(params, "url", nil) || e(session, "url", nil))

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
       # a slug, not a localised verb: it arrives in a query param, so localising it upstream made
       # the URL differ per locale and rendered whatever text happened to arrive
       interaction_type(e(params, "type", nil) || e(session, "type", nil))
     )
     |> assign(
       :federating?,
       module_enabled?(Bonfire.Federate.ActivityPub) and
         Bonfire.Federate.ActivityPub.federating?()
     )
     |> Bonfire.UI.Me.LoginLive.assign_defaults(params, session)
     |> Bonfire.UI.Me.SignupLive.assign_defaults(params, session, form_key: :signup_form)}
  end

  # the AP id of the page's Media post, created when missing under the embed's rules (an import author, else the signed-in user); the embed can link here from a page rendered before an import author was configured
  defp page_post_ap_id(media_uri, params, socket) do
    creator =
      maybe_apply(Bonfire.UI.Social.EmbedThreads, :creator, [current_user(socket)],
        fallback_return: nil
      )

    with {:ok, media} <-
           maybe_apply(
             Bonfire.UI.Social.EmbedThreads,
             :get_or_create,
             [media_uri, params, creator],
             fallback_return: nil
           ),
         ap_id when is_binary(ap_id) <-
           Bonfire.Common.URIs.canonical_url(media, preload_if_needed: true) do
      ap_id
    else
      _ -> nil
    end
  end

  # any slug naming a real verb is accepted, rather than a fixed list that would silently rewrite
  # a new interaction to "follow"; unresolvable input is not echoed back, since it arrives from a
  # query param
  defp interaction_type(type) when is_binary(type) do
    if Bonfire.Boundaries.Verbs.verb_name(Types.maybe_to_atom!(type)), do: type, else: "follow"
  end

  defp interaction_type(_), do: "follow"

  def generate_url(type, name, url, opts) do
    assigns = assigns(opts)

    go =
      e(assigns, :go, nil) ||
        e(assigns, :__context__, :go, nil) ||
        e(assigns, :__context__, :current_params, "go", nil)

    "/remote_interaction?type=#{type}&name=#{name}&url=#{url}&go=#{go}"
  end
end
