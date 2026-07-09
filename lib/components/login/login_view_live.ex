defmodule Bonfire.UI.Me.LoginViewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop form, :any
  prop error, :any
  prop go, :any, default: nil
  prop passwordless_only?, :boolean, default: false
  prop external_signup_url, :string, default: nil
  prop gated_login_message, :string, default: nil
end
