defmodule Bonfire.UI.Me.SettingsViewsLive.ImportLive do
  use Bonfire.UI.Common.Web, :stateful_component

  prop selected_tab, :string

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(
       trigger_submit: false,
       uploaded_files: []
     )
     |> assign(assigns)
     |> allow_upload(:file,
       accept: ~w(.csv),
       # TODO: make extensions & size configurable
       max_file_size: 500_000_000,
       max_entries: 1,
       auto_upload: true
       #  progress: &handle_progress/3
     )}
  end

  def do_handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def do_handle_event("import", %{"type" => type} = _params, socket) do
    case uploaded_entries(socket, :file) do
      {[_ | _] = entries, []} ->
        with [%{ok: queued}] <-
               (for entry <- entries do
                  maybe_consume_uploaded_entry(socket, entry, fn %{path: path} ->
                    debug(path)
                    # debug(entry)
                    # with %{ok: num} <-
                    # do
                    Bonfire.Social.Graph.Import.import_from_csv_file(
                      maybe_to_atom(type),
                      current_user_required!(socket),
                      path
                    )

                    #   {:ok, "#{num}"}
                    # end
                  end)
                end)
               |> debug() do
          {
            :noreply,
            socket
            |> assign_flash(:info, "#{queued} items queued for import :-)")
            # |> update(:uploaded_files, &(&1 ++ uploaded_files))
          }
        end

      _ ->
        {:noreply, socket}
    end
  end

  # def handle_progress(
  #       type,
  #       entry,
  #       socket
  #     ),
  #     do:
  #       Bonfire.UI.Common.LiveHandlers.handle_progress(
  #         type,
  #         entry,
  #         socket,
  #         __MODULE__,
  #         Bonfire.Files.LiveHandler
  #       )

  def handle_event(
        action,
        attrs,
        socket
      ),
      do:
        Bonfire.UI.Common.LiveHandlers.handle_event(
          action,
          attrs,
          socket,
          __MODULE__,
          &do_handle_event/3
        )
end
