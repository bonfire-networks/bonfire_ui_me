defmodule Bonfire.UI.Me.SwitchUserMenuItemsLive do
  @moduledoc """
  Profile switcher in the user menu. With the `show_switch_users_inline` setting on, the account's other profiles (and whether each has anything unseen) are only loaded once the menu is opened: its trigger pushes `load` here, see `Bonfire.UI.Common.UserMenuLive`.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Me.Users

  # nil until the menu is first opened
  data account_users, :any, default: nil
  data unseen_user_ids, :list, default: []
  # no defaults, so `assign_new` in `update/2` computes them once
  data max_users_per_account, :integer
  data show_inline_users, :boolean

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     socket
     |> assign_new(:max_users_per_account, fn ->
       Config.get([Bonfire.Me.Users, :max_per_account], 6, :bonfire_me)
     end)
     |> assign_new(:show_inline_users, fn ->
       Settings.get([Bonfire.Me.Users, :show_switch_users_inline], false,
         current_user: current_user(socket)
       ) == true
     end)}
  end

  def handle_event(
        "load",
        _params,
        %{assigns: %{account_users: nil, show_inline_users: true}} = socket
      ) do
    account = current_account(socket) || current_account_id(socket)
    current_user_id = current_user_id(socket)

    account_users =
      if account do
        (Users.by_account(account) || [])
        |> Enum.reject(&(id(&1) == current_user_id or !e(&1, :character, :username, nil)))
      else
        []
      end

    {:noreply,
     assign(socket,
       account_users: account_users,
       unseen_user_ids: unseen_user_ids(account_users, account)
     )}
  end

  def handle_event("load", _params, socket), do: {:noreply, socket}

  defp unseen_user_ids(users, account) do
    for user <- users,
        Enum.any?(
          [e(user, :character, :notifications_id, nil), e(user, :character, :inbox_id, nil)],
          fn feed_id ->
            # Seen is tracked per-account, and the profile structs don't carry it (see issue #2220)
            feed_id &&
              maybe_apply(
                Bonfire.Social.FeedActivities,
                :any_unseen?,
                [feed_id, [current_user: user, current_account: account]],
                fallback_return: false
              ) == true
          end
        ),
        do: id(user)
  end
end
