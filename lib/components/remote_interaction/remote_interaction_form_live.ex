defmodule Bonfire.UI.Me.RemoteInteractionFormLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop canonical_url, :string, required: true
  prop name, :string, required: true
  prop interaction_type, :string, default: "follow"

  slot header
end
