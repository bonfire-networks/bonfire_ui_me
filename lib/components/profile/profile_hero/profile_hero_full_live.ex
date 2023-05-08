defmodule Bonfire.UI.Me.ProfileHeroFullLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Me.Integration
  # import Bonfire.Common.Media

  prop user, :map
  prop character_type, :atom, default: nil
  prop follows_me, :boolean, default: false
  prop selected_tab, :string
  prop transparent_header, :boolean, default: false
  prop block_status, :any, default: nil
  prop showing_within, :atom, default: :profile
  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url
end
