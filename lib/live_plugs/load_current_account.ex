defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentAccount do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Accounts
  # alias Bonfire.Data.Identity.Account

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(params \\ nil, session, socket)

  # the non-live plug already supplied the current account
  def mount(_, _, %{assigns: %{current_account: _}} = socket) do
    {:ok, socket}
  end

  # current account is already in context
  def mount(
        _,
        _,
        %{assigns: %{__context__: %{current_account: _}}} = socket
      ) do
    {:ok, socket}
  end

  def mount(_, %{"current_account_id" => account_id}, socket)
      when is_binary(account_id) do
    account = Accounts.get_current(account_id)
    {:ok, assign_global(socket, current_account: account, current_account_id: uid(account))}
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, current_account: nil, current_account_id: nil)}
  end
end
