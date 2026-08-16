defmodule Bonfire.UI.Me.LivePlugs.LoadingScreenTest do
  @moduledoc """
  On a disconnected mount `LoadCurrentUser` skips loading the user, keeping only the ids and setting
  `__loading_screen__` (see `maybe_assign_current_user/2`). A guard plug that halts on "no account"
  would then reject everyone before the socket ever connects — which is exactly what `AdminRequired`
  did, and how the console page came to redirect admins to `/login`.

  That phase needs no guard of its own: it runs inside the HTTP request, which has already passed
  the equivalent `Plug`. The real check belongs on the connected mount, where the user is loaded.

  Note these call the plugs directly rather than driving a request: `maybe_assign_current_user/2`
  has `Config.env() == :test` in its condition, so a test request always takes the full-load path
  and never reaches the branch this is about. A feature test therefore cannot catch this regression.
  """

  use ExUnit.Case, async: true

  alias Bonfire.UI.Me.LivePlugs.AccountRequired
  alias Bonfire.UI.Me.LivePlugs.AdminRequired

  defp loading_screen_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        # the halt path assigns a flash, so this must exist for the failure case to be observable
        flash: %{},
        __loading_screen__: true,
        current_user: nil,
        current_user_id: "01HZZZZZZZZZZZZZZZZZZZZZZZ",
        current_account_id: "01HYYYYYYYYYYYYYYYYYYYYYYY"
      }
    }
  end

  describe "AdminRequired" do
    test "defers instead of halting while the loading screen is up" do
      assert {:ok, _socket} = AdminRequired.mount(nil, %{}, loading_screen_socket())
    end

    test "still halts once loaded, with no account" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, flash: %{}, current_user: nil, current_account: nil}
      }

      assert {:halt, _socket} = AdminRequired.mount(nil, %{}, socket)
    end
  end

  describe "AccountRequired" do
    test "defers instead of halting while the loading screen is up" do
      assert {:ok, _socket} = AccountRequired.mount(nil, %{}, loading_screen_socket())
    end

    test "still halts once loaded, with no account" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, flash: %{}, current_user: nil, current_account: nil}
      }

      assert {:halt, _socket} = AccountRequired.mount(nil, %{}, socket)
    end
  end

  # The deferral above is only safe because of this: an anonymous visitor can never reach it. The
  # flag is set exclusively by `LoadCurrentUser.disconnected_mount/3`, which is reached only when
  # the session carried a user id (or a user was already in assigns). With no user, the fallback
  # clause assigns `current_user: nil` and sets no flag, so the guards halt exactly as before.
  #
  # If this ever stops holding, the deferral becomes an authentication bypass for the disconnected
  # mount — hence testing the property rather than trusting the reading.
  describe "the loading-screen flag itself" do
    test "is never set for a session with no user" do
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}}}

      assert {:ok, socket} = Bonfire.UI.Me.LivePlugs.LoadCurrentUser.mount(nil, %{}, socket)
      refute socket.assigns[:__loading_screen__]
      refute socket.assigns[:current_user]
    end
  end
end
