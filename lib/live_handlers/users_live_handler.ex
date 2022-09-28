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

  def handle_event(
        "share_user",
        %{"add_shared_user" => emails_or_usernames} = attrs,
        socket
      ) do
    with {:ok, shared_user} <-
           Bonfire.Me.SharedUsers.add_accounts(
             current_user_required(socket),
             emails_or_usernames,
             attrs
           ) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Access granted to the team!"))
       |> assign(members: e(socket, :assigns, :team, []) ++ [shared_user])}
    end
  end

  def handle_event(
        "make_admin",
        %{"username_or_id" => username_or_id} = _attrs,
        socket
      ) do
    with true <- Bonfire.Me.Users.is_admin?(current_user_required(socket)),
         {:ok, user} <- Bonfire.Me.Users.make_admin(username_or_id) do
      {:noreply,
       socket
       |> assign_flash(:info, l("They are now an admin!"))
       |> assign(user: user)}
    end
  end

  def handle_event(
        "revoke_admin",
        %{"username_or_id" => username_or_id} = _attrs,
        socket
      ) do
    with true <- Bonfire.Me.Users.is_admin?(current_user_required(socket)),
         {:ok, user} <- Bonfire.Me.Users.revoke_admin(username_or_id) do
      {:noreply,
       socket
       |> assign_flash(:info, l("They are no longer an admin."))
       |> assign(user: user)}
    end
  end

  def to_tuple(u) do
    {e(u, :profile, :name, "Someone"), ulid(u)}
  end
end
