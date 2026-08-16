defmodule Bonfire.UI.Me.LivePlugs.AdminRequired do
  @moduledoc """
  Halts unless the current account is an instance admin.

  Loads the account if the socket doesn't have one yet (as `Bonfire.UI.Me.LivePlugs.AccountRequired`
  does), and preloads `:instance_admin` before asking.

  That preload is this plug's job rather than `Bonfire.Me.Accounts.is_admin?/1`'s: it deliberately
  returns false for an unloaded assoc instead of preloading, to avoid n+1s and a preload loop. The
  current-user query doesn't load it either (the join in `Bonfire.Me.Users.Queries.current/1` is
  commented out), so an account reached via `current_user` arrives without it — which silently
  rejected genuine admins.

  The preloaded account is assigned back, so the rest of the request reuses it rather than
  discarding the query and paying for it again.

  Defers entirely during the loading-screen phase. On a disconnected mount `LoadCurrentUser` skips
  loading the user (keeping only the ids) and sets `__loading_screen__`, so there is nothing here to
  check and halting would reject everyone before the socket ever connects.

  That phase needs no check of its own: it runs inside the HTTP request, which has already passed
  `Bonfire.UI.Me.Plugs.AdminRequired` via the router pipeline. This plug exists for the *connected*
  mount, which arrives over the websocket and does not re-run plugs. So route it behind
  `pipe_through(:admin_required)` as well — on a route without it, the disconnected mount would be
  unguarded.
  """

  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Accounts

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(params \\ nil, session \\ nil, socket)

  def mount(
        _params,
        _session,
        %{assigns: %{__loading_screen__: true, current_user_id: id}} = socket
      )
      when is_binary(id),
      do: {:ok, socket}

  def mount(_params, session, socket),
    do: check(current_account(socket), session, socket)

  defp check(nil, session, socket) when is_map(session),
    do: Bonfire.UI.Me.LivePlugs.LoadCurrentAccount.mount(session, socket) ~> mount()

  defp check(%Account{} = account, session, socket) do
    account = repo().maybe_preload(account, :instance_admin)

    check(
      Accounts.is_admin?(account),
      session,
      assign_global(socket, current_account: account)
    )
  end

  defp check(true, _session, socket), do: {:ok, socket}

  defp check(_, _session, socket) do
    {:halt,
     socket
     |> assign_flash(:error, l("That page is only accessible to instance administrators."))
     |> redirect_to(path(:login))}
  end
end
