defmodule Bonfire.UI.Me.DeleteUserModalLive do
  @moduledoc """
  The content of a member row's "Delete user & data" modal: a user who isn't blocked instance-wide yet is explained why not, a blocked one gets the links into the sudo gate for deleting this profile and, if local, the whole account with the count of profiles that go with it. Mounted only when the modal opens, so the one COUNT query costs nothing for rows nobody opens.
  """
  use Bonfire.UI.Common.Web, :stateful_component

  prop user, :map, required: true
  prop is_local_user, :any, default: nil
  prop blocked, :boolean, default: false
  data profile_count, :integer, default: nil
  data target_admin, :boolean, default: false

  @doc false
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    profile_count =
      if socket.assigns.blocked and socket.assigns.is_local_user,
        do: Bonfire.Me.Accounts.count_profiles_of_account_of(socket.assigns.user)

    # one EXISTS query when the modal opens, and none for a remote user, who has no account here
    target_admin =
      socket.assigns.is_local_user == true and
        Bonfire.Me.Accounts.admin_account_of?(socket.assigns.user)

    {:ok, assign(socket, profile_count: profile_count, target_admin: target_admin)}
  end

  @doc "The link into the sudo gate for the given action, with the user to act on."
  def confirm_path(action, user, is_local_user \\ nil) do
    path(:sudo_confirm) <>
      "?" <>
      URI.encode_query(
        action: "Bonfire.Me.SensitiveActions.#{action}",
        target: id(user),
        go: back_path(is_local_user)
      )
  end

  # the tab the delete started from, which the done page links back to
  defp back_path(true), do: "/settings/instance/members"
  defp back_path(_), do: "/settings/instance/remote_users"
end
