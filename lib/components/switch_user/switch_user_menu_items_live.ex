defmodule Bonfire.UI.Me.SwitchUserMenuItemsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Me.Users

  def render(assigns) do
    assigns
    |> assign_new(:max_users_per_account, fn ->
      Config.get([Bonfire.Me.Users, :max_per_account], 4, :bonfire_me)
    end)
    |> assign_new(:show_inline_users, fn ->
      Settings.get([Bonfire.Me.Users, :show_switch_users_inline], false,
        current_user: current_user(assigns)
      )
    end)
    |> assign_new(:current_account_users, fn ->
      e(assigns, :__context__, :current_account_users, [])
      #   if assigns[:current_account] do
      #     Users.by_account(assigns.current_account) |> filter_empty([])
      #   else
      #     []
      #   end
    end)
    |> render_sface()
  end
end
