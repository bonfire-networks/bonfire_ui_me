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

  def handle_event("delete_user", %{"password" => password}, socket) do
    delete = current_user_auth!(socket, password)

    after_delete(
      Bonfire.Me.DeleteWorker.enqueue_delete(delete),
      "/settings/deleted/user/#{id(delete)}",
      socket
    )
  end

  def handle_event("delete_account", %{"password" => password}, socket) do
    delete = current_account_auth!(socket, password)

    after_delete(
      Bonfire.Me.DeleteWorker.enqueue_delete(delete),
      "/settings/deleted/account/#{id(delete)}",
      socket
    )
  end

  def handle_event("fetch_outbox", _, socket) do
    ActivityPub.Federator.Fetcher.fetch_outbox([pointer: socket.assigns[:user]],
      fetch_collection: :async
    )

    {:noreply, socket}
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
       |> assign(members: e(socket, :assigns, :team, []) ++ [shared_user])}
    end
  end

  def handle_event(
        "make_admin",
        params,
        socket
      ) do
    with true <- Bonfire.Me.Accounts.is_admin?(socket.assigns[:__context__]),
         {:ok, user} <-
           Bonfire.Me.Users.make_admin(socket.assigns[:user] || params["username_or_id"]) do
      {:noreply,
       socket
       |> assign_flash(:info, l("They are now an admin!"))
       |> assign(user: user)}
    end
  end

  def handle_event(
        "revoke_admin",
        params,
        socket
      ) do
    with true <- Bonfire.Me.Accounts.is_admin?(socket.assigns[:__context__]),
         {:ok, user} <-
           Bonfire.Me.Users.revoke_admin(socket.assigns[:user] || params["username_or_id"]) do
      {:noreply,
       socket
       |> assign_flash(:info, l("They are no longer an admin."))
       |> assign(user: user)}
    end
  end

  def to_tuple(u) do
    {e(u, :profile, :name, "Someone"), ulid(u)}
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

    renew_session(conn)
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    Phoenix.Controller.delete_csrf_token()

    conn
    |> Plug.Conn.configure_session(renew: true)
    |> Plug.Conn.clear_session()
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
