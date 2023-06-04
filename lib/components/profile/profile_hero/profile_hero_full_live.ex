defmodule Bonfire.UI.Me.ProfileHeroFullLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Bonfire.UI.Me.Integration
  # import Bonfire.Common.Media

  prop user, :map
  prop object, :map
  prop object_id, :string, default: nil
  prop boundary_preset, :any, default: nil
  prop ghosted?, :boolean, default: nil
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil
  prop character_type, :atom, default: nil
  prop follows_me, :boolean, default: false
  prop selected_tab, :string
  prop block_status, :any, default: nil
  prop showing_within, :atom, default: :profile
  prop path, :string, default: "@"
  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url

  def preload([%{skip_preload: true}] = list_of_assigns) do
    list_of_assigns
  end

  def preload(list_of_assigns) do
    Bonfire.Social.Block.LiveHandler.preload(list_of_assigns, caller_module: __MODULE__)
  end

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__
          # &do_handle_event/3
        )
end
