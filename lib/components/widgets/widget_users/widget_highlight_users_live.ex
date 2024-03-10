defmodule Bonfire.UI.Me.WidgetHighlightUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  # 1 hours
  @default_cache_ttl 1_000 * 60 * 60 * 1
  def list_users() do
    Cache.maybe_apply_cached(&do_list_users/0, [], ttl: @default_cache_ttl)
  end

  defp do_list_users() do
    Bonfire.Me.Users.list_paginated(
      #  current_user: current_user, # TODO for respecting blocks/boundaries
      paginate: [limit: 5]
    )
  end
end
