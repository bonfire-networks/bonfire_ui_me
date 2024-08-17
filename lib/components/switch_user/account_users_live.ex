defmodule Bonfire.UI.Me.SwitchUserViewLive.AccountUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # alias Bonfire.UI.Me.CreateUserLive

  prop current_account_users, :any
  prop max_users_per_account, :any, default: 4
  prop go, :any
end
