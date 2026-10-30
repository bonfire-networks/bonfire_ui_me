defmodule Bonfire.UI.Me.WidgetUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop users, :any, default: []
  prop widget_title, :string, default: nil
  prop with_batch_follow, :boolean, default: true
  prop parent_id, :string, default: nil

  @doc "A call to action"
  slot action

  def render(assigns) do
    assigns
    |> assign(
      :users,
      users(assigns[:users])
    )
    |> render_sface()
  end

  def users(users) when is_list(users) do
    users
  end

  def users(%{edges: users}) when is_list(users) do
    users
  end

  def users(_) do
    Bonfire.Me.Users.list_declared_moderators()
  end
end
