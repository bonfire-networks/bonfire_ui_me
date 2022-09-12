defmodule Bonfire.UI.Me.SignupFormLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any
  prop invite, :any
  prop auth_second_factor_secret, :any, default: nil
end
