defmodule Bonfire.UI.Me.WidgetHighlightUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop widget_title, :string, default: nil

  # 1 hours
  @default_cache_ttl 1_000 * 60 * 60 * 1
  def list_users() do
    Cache.maybe_apply_cached(
      &do_list_users/1,
      [
        #  current_user: current_user_id, # TODO for respecting blocks/boundaries (but then can't have a single cache)
        paginate: [limit: 5]
      ],
      expire: @default_cache_ttl
    )
  end

  defp do_list_users(opts) do
    Bonfire.Me.Users.list_paginated(opts)
  end
end
