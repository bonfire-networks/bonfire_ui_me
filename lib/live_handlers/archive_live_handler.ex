defmodule Bonfire.Me.Archive.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  # import Bonfire.Boundaries.Integration

  def handle_event("prepare_archive", _params, socket) do
    {:ok, task_pid} =
      Bonfire.UI.Me.ExportController.trigger_prepare_archive_async(socket.assigns[:__context__])

    # Process.send_after(self(), :clear_flash, 3000)

    {:noreply,
     socket
     |> assign(:export_task_pid, task_pid)
     |> assign_flash(
       :info,
       l(
         "Preparing your archive... You will notified here when it is ready to download (you can continue browsing Bonfire but please keep it open)."
       )
     )}
  end

  def handle_event("cancel_archive", _params, socket) do
    {:noreply,
     case socket.assigns[:export_task_pid] do
       nil ->
         assign_flash(socket, :error, "No export task found")

       task_pid ->
         Process.exit(task_pid, :kill)
         # display it was cancelled.
         assign_flash(socket, :info, "Cancelled")
     end}
  end
end
