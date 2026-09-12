defmodule Bonfire.UI.Me.ProfileLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :any, default: nil

  prop href, :string, default: nil
  prop text, :string, default: nil

  prop metadata, :any, default: nil
  prop show_icon, :boolean, default: true
  prop show_destination, :boolean, default: false

end
