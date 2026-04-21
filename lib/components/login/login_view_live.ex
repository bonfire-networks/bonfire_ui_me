defmodule Bonfire.UI.Me.LoginViewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop form, :any
  prop error, :any
  prop go, :any, default: nil
  prop passwordless_only?, :boolean, default: false
end
