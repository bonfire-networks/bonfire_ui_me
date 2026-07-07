defmodule Bonfire.UI.Me.CreateUserViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop suggested_name, :string, default: ""
end
