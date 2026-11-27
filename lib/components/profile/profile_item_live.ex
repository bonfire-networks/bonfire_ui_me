defmodule Bonfire.UI.Me.ProfileItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any
  prop lg, :boolean, default: false

  # for narrow places like sidebar widgets, where the default text-base name and handle crowd the space
  prop compact, :boolean, default: false
  prop is_remote, :boolean, default: nil

  prop wrapper_class, :css_class, default: nil

  prop character, :any
  prop show_controls, :list, default: [:follow]
  prop activity_id, :any, default: nil
  prop inline, :boolean, default: false
  prop show_summary, :boolean, default: false
  prop with_popover, :boolean, default: false
  prop avatar_class, :css_class, default: nil
  prop fallback_class, :css_class, default: nil
  prop only_img, :boolean, default: false

  prop link_opts, :keyword, default: []

  prop parent_id, :any, default: nil
  prop showing_within, :any, default: nil

  slot default, required: false

  @doc """
  Where the avatar and name link: a remote actor's URL as is, else the local character page.

      iex> Bonfire.UI.Me.ProfileItemLive.profile_href(%{username: "ana"})
      "/character/ana"

      iex> Bonfire.UI.Me.ProfileItemLive.profile_href(%{username: "https://example.social/@ana"})
      "https://example.social/@ana"
  """
  def profile_href(character) do
    case e(character, :username, "") do
      "http" <> _ = url -> url
      username -> "/character/#{username}"
    end
  end
end
