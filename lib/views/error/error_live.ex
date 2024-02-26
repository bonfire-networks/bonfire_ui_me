defmodule Bonfire.UI.Me.ErrorLive do
  use Bonfire.UI.Common.Web, :live_view

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    {
      :ok,
      socket
      |> assign_new(:page, fn -> nil end)
      |> assign_new(:code, fn -> params["code"] end)
      |> assign_new(:message, fn ->
        maybe_apply(Bonfire.Fail, :get_error_msg, params["code"], &default_msg/0) || default_msg()
      end)
      #  |> assign_new(:without_sidebar, fn -> true end)
    }
  end

  defp default_msg, do: l("There was an error.")
end
