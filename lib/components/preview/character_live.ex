defmodule Bonfire.UI.Me.Preview.CharacterLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop object, :any
  prop object_type, :any, default: nil
  prop verb, :any, default: nil
  prop activity, :any, default: nil
  prop verb_display, :string, default: nil
  prop permalink, :string, default: nil
  prop date_ago, :string, default: nil
  prop showing_within, :atom, default: nil
  prop activity_component_id, :string, default: nil

  def render(assigns) do
    current_user = current_user(assigns)
    current_user_id = id(current_user)
    object = e(assigns, :object, nil)
    object_id = id(object) || e(assigns, :activity, :object, :id, nil)
    subject = e(assigns, :activity, :subject, nil)

    assigns
    |> assign(
      :the_character,
      cond do
        e(assigns, :verb, nil) in ["Follow", "Request to Follow"] and object_id == current_user_id ->
          debug(
            "special case for showing the follower instead of the object when I am the one being followed"
          )

          subject

        object_id == current_user_id ->
          current_user

        object_id == id(subject) and not is_map(object) ->
          subject

        true ->
          object
      end
      # |> debug("computed character to show")
    )
    |> render_sface()
  end

  def preloads(),
    do: [
      :character,
      profile: [:icon]
    ]
end
