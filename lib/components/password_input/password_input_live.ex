defmodule Bonfire.UI.Me.PasswordInputLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, required: true
  prop name, :string, required: true
  prop label, :string, default: nil
  prop placeholder, :string, default: nil
  prop autocomplete, :string, default: "current-password"
  prop required, :boolean, default: true
  prop error, :boolean, default: false
end
