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

  def mount(_params, _session, socket) do
    account = current_account(socket)
    # A provisioner (e.g. an external membership integration) may leave a suggested display
    # name on the account so this step can prefill it (still fully editable). Username is not
    # prefilled — it keeps deriving from the name field client-side, as usual.
    suggested_name = suggested_profile_name(account)

    {:ok,
     socket
     |> assign(:page, l("Create a new user profile"))
     |> assign(:page_title, l("Create a new user profile"))
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
       #      4, :bonfire_me
       #    )
     )}
  end

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
