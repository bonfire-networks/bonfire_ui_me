defmodule Bonfire.UI.Me.LivePlugs.AccountRequired do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.Account

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(params \\ nil, session \\ nil, socket)

  # Defers while the loading screen is up: on a disconnected mount `LoadCurrentUser` keeps only the ids, so there is nothing to check yet and halting would reject a signed-in user before the socket connects. That phase runs inside the HTTP request, which has already passed `Bonfire.UI.Me.Plugs.AccountRequired`. Matching on `current_user_id` rather than the flag alone means this defers on evidence the session carried a user, so a loading screen that ever appeared for a guest would fail closed.
  def mount(
        _params,
        _session,
        %{assigns: %{__loading_screen__: true, current_user_id: id}} = socket
      )
      when is_binary(id),
      do: {:ok, socket}

  def mount(_params, session, socket),
    do: check(current_account(socket), session, socket)

  defp check(%Account{id: _}, _, socket), do: {:ok, socket}

  defp check(nil, session, socket) when is_map(session),
    do: Bonfire.UI.Me.LivePlugs.LoadCurrentAccount.mount(session, socket) ~> mount()

  defp check(_, _, socket), do: no(socket)

  defp no(socket) do
    {:halt,
     socket
     |> assign_flash(:error, l("You need to log in first."))
     |> redirect_to(path(:login))}
  end
end
