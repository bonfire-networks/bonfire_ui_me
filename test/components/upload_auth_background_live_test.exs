defmodule Bonfire.UI.Me.UploadAuthBackgroundLiveTest do
  @moduledoc "An upload under a name this component did not allow is ignored, instead of being handed back to itself forever."
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  test "the progress of an upload with an unknown name returns instead of recursing" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}
    parent = self()

    # run apart with a capped heap, so a runaway recursion kills the process rather than the test run
    {pid, ref} =
      :erlang.spawn_opt(
        fn ->
          send(
            parent,
            {:done, Bonfire.UI.Me.UploadAuthBackgroundLive.handle_progress(:unknown, %{}, socket)}
          )
        end,
        [:monitor, {:max_heap_size, %{size: 5_000_000, kill: true, error_logger: false}}]
      )

    assert_receive {:done, {:noreply, %Phoenix.LiveView.Socket{}}}, 5_000

    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
  end
end
