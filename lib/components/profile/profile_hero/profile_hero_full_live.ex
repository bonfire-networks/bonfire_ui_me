defmodule Bonfire.UI.Me.ProfileHeroFullLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Me.Integration

  prop user, :map
  prop follows_me, :boolean, default: false
  prop selected_tab, :string
  
  def display_url("https://"<>url), do: url
  def display_url("http://"<>url), do: url
  def display_url(url), do: url

end
