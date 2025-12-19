defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentUserCircles do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Boundaries.Circles
  alias Bonfire.Data.Identity.User

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(_, _, %{assigns: %{my_circles: circles}} = socket) when is_list(circles) do
    # already loaded
    {:ok, socket}
  end

  def mount(
        _,
        _,
        %{assigns: %{__context__: %{my_circles: circles}}} = socket
      )
      when is_list(circles) do
    # already loaded
    {:ok, socket}
  end

  def mount(_, _, %{assigns: %{current_user: %User{} = user}} = socket) do
    {:ok,
     assign_global(
       socket,
       :my_circles,
       Circles.list_my_for_sidebar(user, exclude_stereotypes: true, exclude_built_ins: true)
     )}
  end

  def mount(
        _,
        _,
        %{assigns: %{__context__: %{current_user: %User{} = user}}} = socket
      ) do
    {:ok,
     assign_global(
       socket,
       :my_circles,
       Circles.list_my_for_sidebar(user, exclude_stereotypes: true, exclude_built_ins: true)
     )}
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, :my_circles, [])}
  end
end
