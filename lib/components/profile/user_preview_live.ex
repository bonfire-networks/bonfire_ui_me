defmodule Bonfire.UI.Me.UserPreviewLive do
  @moduledoc "Someone as a card (banner, avatar, name, handle, bio, website) or, with `variant={:portrait}`, as an avatar tile. Used by the account switcher, OAuth consent and the circle embed; see team-docs plans/circle-embed-cards.md for the design choices."
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map

  @doc "Where the name links; nil leaves it unlinked, for callers that wrap the whole card in their own link (e.g. the account switcher)"
  prop href, :string, default: nil

  @doc "Link target, e.g. `_blank` in embeds"
  prop target, :string, default: nil

  @doc "Stretch the name link over the whole card; false links only the name and avatar, for cards holding their own controls (e.g. the profile hover card's follow button)"
  prop stretch_link, :boolean, default: true

  prop with_banner, :boolean, default: false

  @doc "Show the bio and website"
  prop with_summary, :boolean, default: false

  @doc "The shared-user label and admin badge, which only make sense inside the app"
  prop show_badges, :boolean, default: true

  @doc "`:card`, or `:portrait` for an avatar tile without a card surface"
  prop variant, :atom, default: :card

  prop class, :css_class, default: ""
  prop parent_id, :any, default: nil

  slot actions, required: false

  data name, :string, default: nil
  data handle, :string, default: nil
  data avatar_url, :string, default: nil
  data banner_url, :string, default: nil

  @doc "The `:card` avatar's props, shared by its linked and unlinked forms"
  data card_avatar, :keyword, default: []

  @doc false
  def render(assigns) do
    user = assigns[:user]

    name = e(user, :profile, :name, nil) || e(user, :character, :username, nil)
    avatar_url = Bonfire.Common.Media.avatar_url(user)
    with_banner = assigns[:with_banner] == true

    assigns
    |> assign(
      name: name,
      handle: Bonfire.Me.Characters.display_username(user, true),
      avatar_url: avatar_url,
      banner_url: with_banner && Bonfire.Common.Media.banner_url(user, fallback: false),
      card_avatar: [
        parent_id: deterministic_dom_id(__MODULE__, id(user), "card", assigns[:parent_id]),
        src: avatar_url,
        user_id: id(user),
        title: name,
        is_remote: !check_is_local?(user, preload_if_needed: false),
        wrapper_class: Surface.css_class(["shrink-0", "-mt-8 size-16": with_banner, "size-12": !with_banner]),
        class:
          Surface.css_class([
            "rounded-full bg-base-300 overflow-hidden [&_img]:size-full [&_img]:object-cover",
            "size-16 ring-4 ring-base-100": with_banner,
            "size-12": !with_banner
          ]),
        bg_class: "size-full"
      ]
    )
    |> render_sface()
  end
end
