defmodule UserAuthLiveMount do
  # import Phoenix.LiveView

  def on_mount(:default, params, session, socket) do
    {:ok, socket} = Bonfire.UI.Me.LivePlugs.LoadCurrentUser.mount(params, session, socket)
    {:cont, socket}
  end
end
