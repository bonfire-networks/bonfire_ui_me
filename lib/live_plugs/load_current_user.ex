defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.SwitchUserLive
  alias Bonfire.Data.Identity.User

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(params \\ nil, session, socket)

  # current user is already in context
  def mount(_, _, %{assigns: %{__context__: %{current_user: _}}} = socket) do
    {:ok, socket}
  end

  # the non-live plug already supplied the current user
  def mount(_, _, %{assigns: %{current_user: user}} = socket) do
    {:ok,
     assign_global(socket,
       current_user: user,
       current_user_id: id(user)
     )}
  end

  def mount(_, %{"user_id" => user_id}, socket) when is_binary(user_id) do
    user = Users.get_current(user_id)

    {:ok,
     assign_global(socket,
       current_user: user,
       current_user_id: id(user)
     )}
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, current_user: nil, current_user_id: nil)}
  end
end
