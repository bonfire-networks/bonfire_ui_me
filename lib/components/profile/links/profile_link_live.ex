defmodule Bonfire.UI.Me.ProfileLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :any, default: nil

  prop href, :string, default: nil
  prop icon, :any, default: nil
  prop text, :string, default: nil

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url
end
