defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentAccountUsers do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  alias Bonfire.Data.Identity.Account

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  # from the plug
  def mount(_, _, %{assigns: %{current_account_users: _}} = socket) do
    {:ok, socket}
  end

  # based on account
  def mount(
        _,
        _,
        %{assigns: %{current_account: %Account{} = account, current_user: %{id: user_id}}} =
          socket
      ) do
    {:ok,
     assign_global(socket,
       current_account_users: Users.by_account!(account, exclude_user_id: user_id)
     )}
  end

  def mount(
        _,
        _,
        %{assigns: %{current_account: %Account{} = account, current_user_id: user_id}} = socket
      ) do
    {:ok,
     assign_global(socket,
       current_account_users: Users.by_account!(account, exclude_user_id: user_id)
     )}
  end

  def mount(_, _, %{assigns: %{current_account: %Account{} = account}} = socket) do
    {:ok, assign_global(socket, current_account_users: Users.by_account!(account))}
  end

  # based on account in context
  def mount(
        _,
        _,
        %{
          assigns: %{
            __context__: %{current_account: %Account{} = account, current_user: %{id: user_id}}
          }
        } = socket
      ) do
    {:ok,
     assign_global(socket,
       current_account_users: Users.by_account!(account, exclude_user_id: user_id)
     )}
  end

  def mount(
        _,
        _,
        %{
          assigns: %{
            __context__: %{current_account: %Account{} = account, current_user_id: user_id}
          }
        } = socket
      ) do
    {:ok,
     assign_global(socket,
       current_account_users: Users.by_account!(account, exclude_user_id: user_id)
     )}
  end

  def mount(
        _,
        _,
        %{assigns: %{__context__: %{current_account: %Account{} = account}}} = socket
      ) do
    {:ok, assign_global(socket, current_account_users: Users.by_account!(account))}
  end

  # based on account in user
  def mount(
        _,
        _,
        %{assigns: %{current_user: %{account: %Account{} = account, id: user_id}}} = socket
      ) do
    {:ok,
     assign_global(socket,
       current_account_users: Users.by_account!(account, exclude_user_id: user_id)
     )}
  end

  def mount(_, _, %{assigns: %{current_user: %{account: %Account{} = account}}} = socket) do
    {:ok, assign_global(socket, current_account_users: Users.by_account!(account))}
  end

  # def mount(_, _, %{assigns: %{current_account_id: id}} = socket) when is_binary(id) do
  #   {:ok, assign_global(socket, current_account_users: Users.by_account!(id))}
  # end

  def mount(_, _, socket), do: {:ok, assign(socket, :current_account_users, [])}
end
