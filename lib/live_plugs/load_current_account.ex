defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentAccount do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Accounts
  alias Bonfire.Data.Identity.Account

  # the non-live plug already supplied the current account
  def mount(_, _, %{assigns: %{current_account: %Account{}}} = socket) do
    {:ok, socket}
  end

  # current account is already in context
  def mount(
        _,
        _,
        %{assigns: %{__context__: %{current_account: %Account{}}}} = socket
      ) do
    {:ok, socket}
  end

  def mount(_, %{"account_id" => account_id}, socket)
      when is_binary(account_id) do
    account = Accounts.get_current(account_id)
    {:ok, assign_global(socket, current_account: account, current_account_id: ulid(account))}
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, current_account: nil, current_account_id: nil)}
  end
end
