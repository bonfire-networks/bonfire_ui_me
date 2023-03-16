defmodule UserAuthLiveMount do
  # used for Rauversion extension

  def on_mount(type, params, session, socket) do
    Bonfire.UI.Me.LivePlugs.LoadCurrentUser.on_mount(type, params, session, socket)
  end
end
