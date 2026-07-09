defmodule Bonfire.UI.Me.CreateUserViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop suggested_name, :string, default: ""

  # "organisation" makes this an org shared-user profile (shows the label field, carried through on submit); nil/otherwise is a personal profile
  prop type, :string, default: nil
  prop label, :string, default: nil

  # the account's existing personas, for choosing the org's first co-manager (see create_user_view_live.sface)
  prop account_users, :list, default: []
end
