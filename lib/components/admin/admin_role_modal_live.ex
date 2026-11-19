defmodule Bonfire.UI.Me.AdminRoleModalLive do
  @moduledoc """
  The content of the confirmation to make someone an instance admin (with the option to declare them a moderator too), or with `revoke`, to revoke their admin powers. Its form submits to `Bonfire.Me.Users:make_admin` or `:revoke_admin`, which check that the person acting is an admin. Opened from a user's menu (`Bonfire.UI.Me.AdminRoleLive`), or from the server once someone is picked in the admins page search (`Bonfire.UI.Me.AdminRoleLive.open_make_admin/1`).
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map, required: true
  prop revoke, :boolean, default: false
end
