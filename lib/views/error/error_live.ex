defmodule Bonfire.UI.Me.ErrorLive do
  use Bonfire.UI.Common.Web, :live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    code = params["code"]
    flash_reason = Phoenix.Flash.get(socket.assigns[:flash] || %{}, :error)

    # only asked when there IS a code: `get_error_msg(nil)` answers with the `nil` entry's generic 500 message ("There was an error."), which is a string, so it always won and the flash a redirect carried (e.g. "Not found") was never shown
    headline =
      (code && maybe_apply(Bonfire.Fail, :get_error_msg, code, fn -> nil end)) ||
        flash_reason ||
        default_msg()

    {
      :ok,
      socket
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:code, fn -> code end)
      |> assign_new(:message, fn -> headline end)
      |> assign_new(:page_title, fn -> headline end)
    }
  end

  defp default_msg, do: l("Something didn't load")
end
