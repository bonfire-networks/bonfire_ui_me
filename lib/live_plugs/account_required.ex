defmodule Bonfire.UI.Me.LivePlugs.AccountRequired do
  use Bonfire.UI.Common.Web, :live_plug
  alias Bonfire.Data.Identity.Account

  @behaviour Bonfire.UI.Common.LivePlugModule

  def on_mount(:default, params, session, socket) do
    with {:ok, socket} <- mount(params, session, socket) do
      {:cont, socket}
    end
  end

  def mount(_params \\ nil, session \\ nil, socket),
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
