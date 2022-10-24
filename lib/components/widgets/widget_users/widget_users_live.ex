defmodule Bonfire.UI.Me.WidgetUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop users, :any, default: []
  prop widget_title, :string, default: nil

  def users(users) when is_list(users) do
    users
  end

  def users(%{edges: users}) when is_list(users) do
    users
  end

  def users(_) do
    list_admins()
  end

  def list_admins() do
    repo().maybe_preload(Bonfire.Me.Users.list_admins(), [:character, profile: :icon])
  end
end
