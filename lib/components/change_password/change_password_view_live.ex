defmodule  Bonfire.UI.Me.ChangePasswordViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any, default: ""
  prop resetting_password, :boolean, default: false
end