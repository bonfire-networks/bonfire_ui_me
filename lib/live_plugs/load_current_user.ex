defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.SwitchUserLive
  alias Bonfire.Data.Identity.User

  # current user is already in context
  def mount(_, _, %{assigns: %{__context__: %{current_user: %User{}}}} = socket) do
    {:ok, socket}
  end

  # the non-live plug already supplied the current user
  def mount(_, _, %{assigns: %{current_user: %User{} = user}} = socket) do
    {:ok, assign_global(socket, current_user: user)}
  end

  def mount(_, %{"user_id" => user_id}, socket) when is_binary(user_id) do
    {:ok, assign_global(socket, current_user: Users.get_current(user_id))}
  end

  def mount(_, _params, socket) do
    {:ok, assign_global(socket, current_user: nil)}
  end
end
