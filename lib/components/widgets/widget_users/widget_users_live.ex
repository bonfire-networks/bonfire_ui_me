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
    list_admins()
  end

  # 6 hours
  @default_cache_ttl 1_000 * 60 * 60 * 6

  @doc """
  Lists instance admins (cached 6h). Pass the standard `:cache` opt (`cache: :refresh` busts +
  recomputes — the admins widget's manual refresh button).
  """
  def list_admins(opts \\ []) do
    Cache.maybe_apply_cached(
      &do_list_admins/0,
      [],
      Keyword.put_new(opts, :expire, @default_cache_ttl)
    )
  end

  defp do_list_admins() do
    repo().maybe_preload(Bonfire.Me.Users.list_admins(), [:character, profile: :icon])
  end
end
