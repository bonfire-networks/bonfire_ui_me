defmodule Bonfire.UI.Me.UploadAuthBackgroundLive do
  @moduledoc "Upload component for the auth page background image. Uses a no-resize uploader to preserve full resolution."
  use Bonfire.UI.Common.Web, :stateful_component

  prop src, :string, default: nil
  prop object, :any, default: nil
  prop boundary_verb, :atom, default: :describe
  prop set_field, :any, default: nil
  prop set_fn, :any, default: nil

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(trigger_submit: false, uploaded_files: [])
     |> assign(assigns)
     |> allow_upload(:auth_background,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_file_size: Bonfire.UI.Me.AuthBackgroundUploader.max_file_size(),
       max_entries: 1,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  def handle_progress(:auth_background, entry, socket) do
    user = current_user_required!(socket)
    object = e(assigns(socket), :object, nil)
    boundary_verb = e(assigns(socket), :boundary_verb, nil) || :describe
    set_field = e(assigns(socket), :set_field, nil)
    set_fn = e(assigns(socket), :set_fn, nil)

    if user &&
         (id(user) == id(object) or
            maybe_apply(Bonfire.Boundaries, :can?, [user, boundary_verb, object])) &&
         entry.done? do
      with %{} = uploaded_media <-
             maybe_consume_uploaded_entry(socket, entry, fn %{path: path} = metadata ->
               Bonfire.UI.Me.AuthBackgroundUploader.upload(user, path, %{
                 client_name: entry.client_name,
                 metadata: metadata[entry.ref]
               })
             end) do
        if set_fn do
          set_fn.(:banner, object || user, uploaded_media, set_field, socket)
        else
          {:noreply, socket}
        end
      end
    else
      {:noreply, socket}
    end
  end

  def handle_progress(type, entry, socket) do
    Bonfire.UI.Common.LiveHandlers.handle_progress(
      type,
      entry,
      socket,
      __MODULE__,
      __MODULE__
    )
  end
end
