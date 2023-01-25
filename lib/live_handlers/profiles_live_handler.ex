defmodule Bonfire.Me.Profiles.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  import Bonfire.Common.Text

  # TODO: use Profiles context instead?
  alias Bonfire.Me.Users

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "save",
        _data,
        %{assigns: %{trigger_submit: trigger_submit}} = socket
      )
      when trigger_submit == true do
    {
      :noreply,
      assign(socket, trigger_submit: false)
    }
  end

  def handle_event("save", params, socket) do
    # params = input_to_atoms(params)

    with {:ok, _edit_profile} <-
           Users.update(current_user_required!(socket), params, current_account(socket)) do
      # debug(icon: Map.get(params, "icon"))
      cond do
        # handle controller-based upload
        Text.strlen(Map.get(params, "icon")) > 0 or
            Text.strlen(Map.get(params, "image")) > 0 ->
          {
            :noreply,
            assign(socket, trigger_submit: true)
            |> assign_flash(:info, "Details saved!")
            |> redirect_to("/user")
          }

        true ->
          {:noreply,
           socket
           |> assign_flash(:info, "Profile saved!")
           |> redirect_to("/user")}
      end
    end
  end
end
