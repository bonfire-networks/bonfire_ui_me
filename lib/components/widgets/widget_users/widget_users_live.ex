defmodule Bonfire.UI.Me.WidgetUsersLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop users, :any, default: []
  prop widget_title, :string, default: nil
  prop with_batch_follow, :boolean, default: true
  prop parent_id, :string, default: nil

  @doc "The block's refresh button: its event and who sees it, as `Bonfire.UI.Common.WidgetBlockLive`'s `reset_cache_event` / `can_reset`."
  prop reset_cache_event, :string, default: nil
  prop can_reset, :boolean, default: nil

  @doc "A call to action"
  slot action

  @doc "Shown under the list, such as a button that acts on all the users at once"
  slot footer

  def render(assigns) do
    assigns
    |> assign(
      :users,
      users(assigns[:users], assigns[:__context__])
    )
    |> render_sface()
  end

  def users(users, _context) when is_list(users) do
    users
  end

  def users(%{edges: users}, _context) when is_list(users) do
    users
  end

  # with no users given, the moderators, as far as the viewer may see them
  def users(_, context) do
    Bonfire.Me.Users.list_visible_moderators(context)
  end
end
