defmodule Bonfire.UI.Me.AdminRoleLive do
  @moduledoc """
  The "Make admin" or "Revoke admin" item of a user's menu (the profile, a members row, an admin circle row), which opens the confirmation in `Bonfire.UI.Me.AdminRoleModalLive`. Shown only to instance admins, and only for local users.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  alias Bonfire.Me.Accounts

  prop user, :map, required: true

  @doc "Whether `user` is an admin, when the caller already knows: needed where the user's account isn't preloaded (e.g. the admin circle's members), as `Accounts.is_admin?/1` would read false there."
  prop is_admin, :boolean, default: nil

  prop parent_id, :any, default: nil

  @doc "Plain text item, for menus whose other items have no icons (e.g. a members row)"
  prop hide_icon, :boolean, default: false

  prop open_btn_wrapper_class, :css_class, default: ""

  @doc "Shows a button with these classes instead of a menu item (e.g. next to Follow in the admins list)"
  prop btn_class, :css_class, default: nil

  @doc "Classes of the modal opener's root, which is `w-full` by default: a button beside other content needs it to shrink to fit"
  prop open_modal_wrapper_class, :css_class, default: nil

  @doc "Opens the confirmation to make `user` an admin, from the server: for a pick in a search, which has no button to open it with. `user` is the loaded user, or the picked entry (with its `id`), which is then loaded."
  def open_make_admin(%Bonfire.Data.Identity.User{} = user) do
    Bonfire.UI.Common.ReusableModalLive.set(
      show: true,
      title_text: l("Make this user an admin?"),
      no_actions: true,
      modal_assigns: [
        modal_component: Bonfire.UI.Me.AdminRoleModalLive,
        user: user,
        revoke: false
      ]
    )

    :ok
  end

  def open_make_admin(picked) do
    case Bonfire.Me.Users.by_id(id(picked)) do
      {:ok, user} -> open_make_admin(user)
      other -> error(other, "Could not find the user to make an admin")
    end
  end

  def admin?(_user, is_admin) when is_boolean(is_admin), do: is_admin
  def admin?(user, _), do: Accounts.is_admin?(user) == true
end
