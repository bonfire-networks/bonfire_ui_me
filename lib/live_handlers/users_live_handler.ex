defmodule Bonfire.Me.Users.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler

  alias Bonfire.Me.Users

  def handle_event("autocomplete", %{"value" => search}, socket),
    do: handle_event("autocomplete", search, socket)

  def handle_event("autocomplete", search, socket) when is_binary(search) do
    options =
      (Users.search(search) || [])
      |> Enum.map(&to_tuple/1)

    # debug(matches)

    {:noreply, assign_global(socket, users_autocomplete: options)}
  end

  def handle_event("delete_user", %{"object_id" => delete}, socket) do
    if Bonfire.Me.Accounts.is_admin?(assigns(socket)[:__context__]) do
      after_delete(
        Bonfire.Me.DeleteWorker.enqueue_delete(delete),
        "/settings/deleted/user/#{id(delete)}",
        socket
      )
    else
      error("Not allowed")
    end
  end

  # admin facility: transfer a user profile to another account, identified by that account's email OR a local @username.
  # `skip_max_per_account: true` lets an admin transfer even into an account that's at its cap.
  def handle_event(
        "transfer_user",
        %{"object_id" => user_id, "transfer_target" => target} = params,
        socket
      ) do
    target = String.trim(to_string(target))

    transfer_opts = [
      current_user: current_user_required!(socket),
      skip_max_per_account: true,
      # if this profile is an admin, hand admin to the destination account too (else it's revoked)
      transfer_admin: not empty?(params["transfer_admin"])
    ]

    with {:ok, _user} <- Users.transfer_to_account(user_id, target, transfer_opts) do
      {:noreply,
       assign_flash(socket, :info, l("Profile transferred to %{target}.", target: target))}
    else
      {:error, :target_not_found} ->
        {:noreply,
         assign_flash(
           socket,
           :error,
           l("No account found for that email or username on this instance.")
         )}

      {:error, :not_permitted} ->
        {:noreply, assign_flash(socket, :error, l("Only an admin can transfer a profile."))}

      e ->
        error(e, "Could not transfer the profile")

        {:noreply, assign_flash(socket, :error, l("Could not transfer the profile."))}
    end
  end

  def handle_event("delete_account", _params, socket) do
    current_account(socket) || Bonfire.Common.Utils.fail_auth(:needs_login)

    {:noreply,
     redirect_to(socket, "/account/confirm?action=Bonfire.Me.SensitiveActions.DeleteAccount")}
  end

  def handle_event("fetch_outbox", params, socket) do
    # the actor the button names (a person, or a group, whose page assigns it as `category` rather than `user`), else the page's own user
    ActivityPub.Federator.Fetcher.fetch_outbox(
      [pointer: assigns(socket)[:user] || e(params, "id", nil)],
      mode: :async,
      fetch_collection: :async,
      fetch_collection_entries: true,
      user_id: current_user_id(socket),
      triggered_by: "LiveHandler:fetch_outbox"
    )

    {:noreply,
     socket
     |> assign_flash(
       :info,
       l("Syncing with remote server. Content will gradually appear in the feed.")
     )}
  end

  def handle_event(
        "share_user",
        %{"add_shared_user" => emails_or_usernames} = attrs,
        socket
      ) do
    with {:ok, shared_user} <-
           Bonfire.Common.Utils.maybe_apply(
             Bonfire.Me.SharedUsers,
             :add_accounts,
             [current_user_required!(socket), emails_or_usernames, attrs]
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Access granted to the team!"))
       |> assign(members: e(assigns(socket), :team, []) ++ [shared_user])}
    end
  end

  def handle_event(
        "remove_team_account",
        %{"id" => id},
        socket
      ) do
    # the roster already holds the user, so we pass its id (no username round-trip; also works when character isn't loaded)
    user = current_user_required!(socket)

    with {:ok, _shared_user} <-
           Bonfire.Common.Utils.maybe_apply(
             Bonfire.Me.SharedUsers,
             :remove_account,
             [user, id, [current_user: user]]
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Removed that team member's access."))}
    end
  end

  def handle_event(
        "make_admin",
        params,
        socket
      ) do
    with {:ok, user} <-
           Bonfire.Me.Users.make_admin(admin_role_target(params, socket),
             current_user: current_user_required!(socket),
             moderator: not empty?(params["moderator"])
           ) do
      Bonfire.UI.Common.OpenModalLive.close()
      update_admins_list(added_member: user)

      {:noreply,
       socket
       |> assign_flash(:info, l("They are now an admin!"))
       |> maybe_assign_admin_role_target(user)}
    else
      {:error, :not_permitted} ->
        {:noreply, assign_flash(socket, :error, l("Only an admin can make someone an admin."))}

      other ->
        error(other, "Could not make them an admin")
        {:noreply, assign_flash(socket, :error, l("Could not make them an admin."))}
    end
  end

  def handle_event(
        "revoke_admin",
        params,
        socket
      ) do
    with {:ok, user} <-
           Bonfire.Me.Users.revoke_admin(admin_role_target(params, socket),
             current_user: current_user_required!(socket)
           ) do
      Bonfire.UI.Common.OpenModalLive.close()
      update_admins_list(removed_member: user)

      {:noreply,
       socket
       |> assign_flash(:info, l("They are no longer an admin."))
       |> maybe_assign_admin_role_target(user)}
    else
      {:error, :not_permitted} ->
        {:noreply, assign_flash(socket, :error, l("Only an admin can revoke an admin."))}

      # eg. the last admin of the instance, which `Users.revoke_admin/1` refuses with a message
      {:error, message} when is_binary(message) ->
        {:noreply, assign_flash(socket, :error, message)}

      other ->
        error(other, "Could not revoke their admin powers")
        {:noreply, assign_flash(socket, :error, l("Could not revoke their admin powers."))}
    end
  end

  # the user the form names: on a page listing many users (the members, the admins), the page's own `:user` assign is not the one acted on
  defp admin_role_target(params, socket) do
    case params["username_or_id"] do
      username_or_id when is_binary(username_or_id) and username_or_id != "" -> username_or_id
      _ -> assigns(socket)[:user]
    end
  end

  # the admins tab of the instance settings lists the admin circle with this id; on any other page there's no such component and the update is dropped
  defp update_admins_list(change) do
    if module = Bonfire.Common.Extend.maybe_module(Bonfire.UI.Boundaries.CircleMembersLive),
      do: maybe_send_update(module, "admin_circle", change)
  end

  # a profile page shows its `:user`'s admin state, so it gets the updated user; other pages have no `:user` to update
  defp maybe_assign_admin_role_target(socket, user) do
    if assigns(socket)[:user], do: assign(socket, user: user), else: socket
  end

  def to_tuple(u) do
    {e(u, :profile, :name, "Someone"), uid(u)}
  end

  @doc "Force-logout a user: disconnect their active WebSocket and add to cache blocklist (60-day TTL) so any existing cookie sessions are invalidated on the next request"
  def force_logout_user(user_id) when is_binary(user_id) do
    Utils.maybe_apply(
      Bonfire.Web.Endpoint,
      :broadcast,
      ["socket_user:#{user_id}", "disconnect", %{}]
    )

    # `expire` is the option name `Cache.put` expects (not `ttl`); `async: false`
    # blocks until the write commits, so admin-block flows can rely on the flag
    # being live before they return.
    Bonfire.Common.Cache.put("force_logout:#{user_id}", true,
      expire: :timer.hours(24 * 60),
      async: false
    )
  end

  @doc "Force-logout all sessions for an account AND all its users"
  def force_logout_account(account_id) when is_binary(account_id) do
    # Disconnect account-level sockets (pre-user-pick sessions)
    Utils.maybe_apply(
      Bonfire.Web.Endpoint,
      :broadcast,
      ["socket_account:#{account_id}", "disconnect", %{}]
    )

    # Per-user: disconnect socket + set cache flag (one iteration for both)
    Bonfire.Me.Users.ids_by_account(account_id)
    |> Enum.each(&force_logout_user/1)
  end

  @doc "Takes a user out of every session that has it selected, keeping their account signed in, eg. once the user is queued for deletion: disconnects its open pages, and on their next request the sessions go to the profile switcher. A user already forced out stays fully logged out."
  def deselect_user_everywhere(user_id) when is_binary(user_id) do
    Utils.maybe_apply(
      Bonfire.Web.Endpoint,
      :broadcast,
      ["socket_user:#{user_id}", "disconnect", %{}]
    )

    if !Bonfire.Common.Cache.get!("force_logout:#{user_id}") do
      Bonfire.Common.Cache.put("force_logout:#{user_id}", :deselect,
        expire: :timer.hours(24 * 60),
        async: false
      )
    end
  end

  @doc "Remove the force-logout flag for a user, re-allowing login"
  def cancel_force_logout_user(user_id) when is_binary(user_id),
    do: Bonfire.Common.Cache.remove("force_logout:#{user_id}")

  @doc "Remove force-logout flags for all users of an account"
  def cancel_force_logout_account(account_id) when is_binary(account_id) do
    Bonfire.Me.Users.ids_by_account(account_id)
    |> Enum.each(&cancel_force_logout_user/1)
  end

  @doc "This function disconnects the user but leaves the account session alone"
  def disconnect_user_session(%{assigns: assigns} = conn) do
    disconnect_user_sockets(assigns)

    conn
    |> Plug.Conn.delete_session(:current_user_id)
  end

  @doc "This function disconnects the user and account, erases the session and CSRF token, and starts a new session"
  def disconnect_account_session(%{assigns: assigns} = conn) do
    disconnect_sockets(assigns)

    Bonfire.UI.Common.Web.renew_session(conn)
  end

  def disconnect_sockets(context) do
    disconnect_user_sockets(context)
    disconnect_account_sockets(context)
  end

  defp disconnect_user_sockets(context) do
    # see https://hexdocs.pm/phoenix_live_view/security-model.html#disconnecting-all-instances-of-a-live-user
    case current_user_id(context) do
      nil ->
        debug("no user sockets found to broadcast the logout to")

      user_id ->
        Utils.maybe_apply(
          Bonfire.Web.Endpoint,
          :broadcast,
          ["socket_user:#{user_id}", "disconnect", %{}]
        )
    end
  end

  defp disconnect_account_sockets(context) do
    case current_account_id(context) do
      nil ->
        debug("no account sockets found to broadcast the logout to")

      account_id ->
        Utils.maybe_apply(
          Bonfire.Web.Endpoint,
          :broadcast,
          ["socket_account:#{account_id}", "disconnect", %{}]
        )
    end
  end

  defp after_delete(result, redirect_after, socket) do
    with {:ok, _} <- result do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(
         :info,
         l(
           "Queued for deletion. Should be done in a few minutes... So long, and thanks for all the fish!"
         )
       )
       |> redirect_to(
         redirect_after,
         fallback: current_url(socket)
       )}
    end
  end
end
