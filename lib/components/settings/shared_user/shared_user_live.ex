defmodule Bonfire.UI.Me.SettingsViewsLive.SharedUserLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop selected_tab, :any

  # the org label (its team/org kind) is captured at creation, so step 2 hides this field; the settings tab shows it to allow relabelling
  prop with_label, :boolean, default: true

  @doc "The specific users co-managing this organisation profile (the invited co-managers and the creator) — the roster's display identities. Never the account's other personas, so nothing leaks."
  def caretaker_users(current_user) do
    list = Bonfire.Me.SharedUsers.list_linked_users(current_user)

    # # TODO: remove this once the roster is always correct and never empty
    # (if show_me_row?(current_user, list),
    #      do:  list ++[%{id: id(current_user), profile:  %{name: "Me"}}],
    #      else: list
    #    )
  end

  @doc "Show a plain \"You\" row when my account co-manages but none of the already-listed `users` is one of my personas (e.g. an account-only creator link, from an org created with no active persona), so the roster isn't empty or missing me. Takes the already-loaded roster `users` to avoid re-querying."
  def show_me_row?(current_user, users) do
    my_id = id(current_user)

    Bonfire.Me.SharedUsers.account_linked?(current_user, current_account(current_user)) and
      not Enum.any?(
        Enums.ids(users),
        &(&1 == my_id)
      )
  end
end
