defmodule Bonfire.UI.Me.ProfileLinksLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :any, default: nil

  prop user, :any, default: nil
  prop aliases, :any, default: []

  # def render(assigns) do
  #   user = assigns[:user]
  #   # debug(assigns)
  #   assigns
  #   |> assign( # NOTE: should not be needed as aliases should be loaded as part of the profile
  #     :aliases,
  #     if(user,
  #       do:
  #         Utils.maybe_apply(
  #           Bonfire.Social.Graph.Aliases,
  #           :list_aliases,
  #           [user]
  #         )
  #         |> debug("list_aliases")
  #         |> e(:edges, []),
  #       else: []
  #     )
  #   )
  #   |> render_sface()
  # end
end
