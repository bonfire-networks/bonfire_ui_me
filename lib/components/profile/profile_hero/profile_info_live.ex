defmodule Bonfire.UI.Me.ProfileInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me.Integration

  prop user, :map

  prop path, :string, default: "@"
  prop selected_tab, :any, default: nil
  prop character_type, :atom, default: nil

  prop follows_me, :boolean, default: false

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url

  slot header
end
