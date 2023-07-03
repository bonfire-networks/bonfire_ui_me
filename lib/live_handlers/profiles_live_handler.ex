defmodule Bonfire.Me.Profiles.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  # import Bonfire.Common.Text

  # TODO: use Profiles context instead?
  alias Bonfire.Me.Users

  def handle_event("add_alias", %{"actor" => actor}, socket) do
    with {:ok, added} <- Bonfire.Social.Aliases.add(current_user_required!(socket), actor) do
      {
        :noreply,
        socket
        |> assign_flash(:info, l("Added the alias!"))
      }
    end
  end

  def handle_event("move_away", %{"actor" => actor}, socket) do
    with {:ok, added} <- Bonfire.Social.Aliases.add(current_user_required!(socket), actor) do
      debug(added)
      handle_event("move_away", %{"user" => added}, socket)
    end
  end

  def handle_event("move_away", %{"user" => target}, socket) do
    user = current_user_required!(socket)

    with {:ok, added} <- Bonfire.Social.Aliases.move(user, target) do
      {
        :noreply,
        socket
        |> assign_flash(
          :info,
          l("The move is underway... Followers will be transferred over the next few hours...")
        )
      }
    else
      {:error, :not_in_also_known_as} ->
        {
          :noreply,
          socket
          |> assign_flash(
            :error,
            l(
              "You need to first add this user (%{username}) as an alias on the instance you want to migrate to. If you have already done so please try again in an hour or so.",
              username: Bonfire.Me.Characters.display_username(user, true)
            )
          )
        }
    end
  end

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

  def set_profile_image(:icon, %{} = user, uploaded_media, assign_field, socket) do
    with {:ok, user} <-
           Bonfire.Me.Users.update(user, %{
             "profile" => %{
               "icon" => uploaded_media,
               "icon_id" => uploaded_media.id
             }
           }) do
      {:noreply,
       socket
       #  |> assign_global(assign_field, deep_merge(user, %{profile: %{icon: uploaded_media}}))
       |> assign_flash(:info, l("Avatar changed!"))
       |> assign(src: Bonfire.Files.IconUploader.remote_url(uploaded_media))
       |> send_self_global({assign_field, deep_merge(user, %{profile: %{icon: uploaded_media}})})}
    end
  end

  def set_profile_image(:banner, %{} = user, uploaded_media, assign_field, socket) do
    debug(assign_field)

    with {:ok, user} <-
           Bonfire.Me.Users.update(user, %{
             "profile" => %{
               "image" => uploaded_media,
               "image_id" => uploaded_media.id
             }
           }) do
      {:noreply,
       socket
       |> assign_flash(:info, l("Background image changed!"))
       |> assign(src: Bonfire.Files.BannerUploader.remote_url(uploaded_media))
       #  |> assign_global(assign_field, deep_merge(user, %{profile: %{image: uploaded_media}}) |> debug)
       |> send_self_global({assign_field, deep_merge(user, %{profile: %{image: uploaded_media}})})}
    end
  end
end
