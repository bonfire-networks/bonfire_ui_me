defmodule Bonfire.UI.Me.LivePlugs.LoadCurrentUser do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Me.Users
  # alias Bonfire.UI.Me.SwitchUserLive
  # alias Bonfire.Data.Identity.User

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  @decorate time()
  def mount(params \\ nil, session, socket)

  def mount(params, session, {:ok, socket} = _) do
    mount(params, session, socket)
  end

  # current user is already in context
  def mount(_, _, %{assigns: %{__context__: %{current_user: _}}} = socket) do
    {:ok, socket}
  end

  # the non-live plug already supplied the current user
  def mount(_, _, %{assigns: %{current_user: user}} = socket) do
    account = e(user, :account, nil)

    {:ok,
     assign_global(socket,
       # user_to_assign(user),
       current_user: user,
       current_user_id: id(user),
       #  current_account: account,
       current_account_id: id(account)
     )}
  end

  def mount(_, %{"current_user_id" => user_id} = session, socket) when is_binary(user_id) do
    user =
      get_current(
        user_id,
        current_account_id(socket.assigns) || session["current_account_id"]
      )

    # |> debug("got_current")

    # account = e(user, :account, nil)

    {:ok,
     socket
     #  |> assign(
     #    current_user: user,
     #    current_account: account
     #  )
     |> assign_global(
       # user_to_assign(user),
       current_user: user,
       current_user_id: id(user),
       #  current_account: account, # do not load the full account (with settings etc) twice into the global assigns here
       # id(account)
       current_account_id: e(user, :account, :id, nil)
     )}
  end

  def mount(_, _, socket) do
    {:ok, assign_global(socket, current_user: nil, current_user_id: nil)}
  end

  def get_current(user_id, account_id) do
    # if ProcessTree.get(:approach_to_current_user)==:cache do
    # Cache.get!("current_user:#{user_id}") ||
    #   Users.get_current(
    #     user_id,
    #     account_id
    #   )
    #   |> Cache.put("current_user:#{user_id}", ...)
    # else
    Users.get_current(
      user_id,
      account_id
    )

    # end
  end

  # def user_to_assign(%{id: id} = user) do
  #   info(if ProcessTree.get(:approach_to_current_user)==:user do
  #     user
  # else
  #      id
  #   end)
  # end
  # def user_to_assign(other), do: other
end
