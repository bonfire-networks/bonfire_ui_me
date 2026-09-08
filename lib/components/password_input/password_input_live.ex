defmodule Bonfire.UI.Me.PasswordInputLive do
  @moduledoc "The shared password field with show/hide toggle, extracted from LoginViewLive so login, change-password and the sudo verify page render one implementation."
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, required: true
  prop name, :string, required: true
  prop label, :string, default: nil
  prop placeholder, :string, default: nil
  prop autocomplete, :string, default: "current-password"
  prop required, :boolean, default: true
  prop error, :boolean, default: false
end
