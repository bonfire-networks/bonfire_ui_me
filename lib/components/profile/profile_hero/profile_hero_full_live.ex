defmodule Bonfire.UI.Me.ProfileHeroFullLive do
  use Bonfire.UI.Common.Web, :stateful_component
  # import Bonfire.UI.Me.Integration
  # import Bonfire.Common.Media

  prop user, :map
  # prop object, :map
  # prop object_id, :string, default: nil
  prop boundary_preset, :any, default: nil

  prop skip_preload, :boolean, default: false
  prop ghosted?, :boolean, default: nil
  prop ghosted_instance_wide?, :boolean, default: nil
  prop silenced?, :boolean, default: nil
  prop silenced_instance_wide?, :boolean, default: nil

  prop character_type, :atom, default: nil
  prop follows_me, :boolean, default: false
  prop selected_tab, :any
  prop block_status, :any, default: nil
  prop showing_within, :atom, default: :profile
  prop path, :string, default: "@"

  prop members, :any, default: nil
  prop moderators, :any, default: nil

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url

  def update(%{skip_preload: true} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  def update(assigns, %{assigns: %{skip_preload: true}} = socket) do
    {:ok, socket |> assign(assigns)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok,
     socket
     |> assign(
       Bonfire.Boundaries.Blocks.LiveHandler.preload_one(
         e(socket.assigns, :user, nil),
         current_user(socket.assigns)
       )
     )}
  end

  # def update_many([{%{skip_preload: true}, _}] = assigns_sockets) do
  #   assigns_sockets
  # end
  # def update_many(assigns_sockets) do
  #   Bonfire.Boundaries.Blocks.LiveHandler.update_many(assigns_sockets, caller_module: __MODULE__)
  # end

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
