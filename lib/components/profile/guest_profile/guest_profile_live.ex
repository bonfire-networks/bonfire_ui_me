defmodule Bonfire.UI.Me.GuestProfileLive do
  use Bonfire.UI.Common.Web, :stateful_component
  prop user, :map
  prop ghosted?, :boolean, default: nil
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil
  prop boundary_preset, :any, default: nil
  prop members, :any, default: nil
  prop moderators, :any, default: nil

  def update_many([{%{skip_preload: true}, _}] = assigns_sockets) do
    assigns_sockets
  end

  def update_many(assigns_sockets) do
    Bonfire.Boundaries.Blocks.LiveHandler.update_many(assigns_sockets, caller_module: __MODULE__)
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
