defmodule Bonfire.UI.Me.ProfileInfoLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me.Integration

  prop user, :map
  prop is_local_user, :any, default: nil

  prop path, :string, default: "@"
  prop selected_tab, :any, default: nil
  prop character_type, :atom, default: nil
  prop silenced_instance_wide?, :boolean, default: false
  prop ghosted_instance_wide?, :boolean, default: false
  prop ghosted?, :boolean, default: false
  prop silenced?, :boolean, default: false
  prop boundary_preset, :any, default: nil

  prop members, :any, default: nil
  prop moderators, :any, default: nil

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url
end
