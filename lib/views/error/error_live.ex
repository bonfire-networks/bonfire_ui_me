defmodule Bonfire.UI.Me.ErrorLive do
  use Bonfire.UI.Common.Web, :live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    code = params["code"]
    flash_reason = Phoenix.Flash.get(socket.assigns[:flash] || %{}, :error)

    headline =
      maybe_apply(Bonfire.Fail, :get_error_msg, code, fn -> nil end) ||
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
