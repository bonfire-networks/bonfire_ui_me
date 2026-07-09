defmodule Bonfire.UI.Me.CreateUserLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  use Bonfire.Common.Settings
  # alias Bonfire.Data.Identity.User
  alias Bonfire.Me.Users

  # alias Bonfire.UI.Me.CreateUserLive

  on_mount {LivePlugs,
   [
     # Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
     Bonfire.UI.Me.LivePlugs.AccountRequired
     # Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers
   ]}

  def mount(params, session, socket) do
    account = current_account(socket)
    # A provisioner (e.g. an external membership integration) may leave a suggested display
    # name on the account so this step can prefill it (still fully editable). Username is not
    # prefilled — it keeps deriving from the name field client-side, as usual.
    suggested_name = suggested_profile_name(account)

    # `type=organisation` (from the switch-user "New organisation profile" button, or preserved on a validation re-render) makes this an organisation shared user; `label` is its team/org kind. The controller passes these through the session (see `paint/2`) so they survive the connected mount; fall back to mount params.
    profile_type = e(session, "profile_type", nil) || e(params, "type", nil)
    profile_label = e(session, "profile_label", nil) || e(params, "label", nil)

    # the account's existing personas, offered as the creator/first co-manager of an org (only shown as a chooser when there's more than one)
    account_users = if profile_type == "organisation", do: Users.by_account(account), else: []

    {:ok,
     socket
     |> assign(:page, page_title(profile_type))
     |> assign(:page_title, page_title(profile_type))
     |> assign(:profile_type, profile_type)
     |> assign(:profile_label, profile_label)
     |> assign(:account_users, account_users)
     |> assign(:suggested_name, suggested_name || "")
     |> assign_new(:form, fn -> user_form(prefill_params(suggested_name), account) end)
     #  |> assign_new(:current_account_users, fn -> nil end)
     |> assign(
       without_sidebar: true,
       no_header: true,
       without_secondary_widgets: true,
       smart_input_opts: %{hide_buttons: true}
       #  max_users_per_account:
       #    Config.get(
       #      [Bonfire.Me.Users, :max_per_account],
       #      6, :bonfire_me
       #    )
     )}
  end

  defp page_title("organisation"), do: l("Create new organisation profile")
  defp page_title(_), do: l("Create new personal profile")

  defp suggested_profile_name(account) do
    account = repo().maybe_preload(account, :settings)

    Settings.get([Bonfire.Me.Users, :suggested_profile_name], nil, current_account: account)
  end

  defp prefill_params(nil), do: %{}
  defp prefill_params(""), do: %{}
  defp prefill_params(name) when is_binary(name), do: %{profile: %{name: name}}

  defp user_form(params \\ %{}, account),
    do: Users.changeset(:create, params, account)
end
