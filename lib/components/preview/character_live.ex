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

  def the_other(activity, object, context) do
    current_user = current_user(context)

    if e(activity, :verb, :verb, nil) in ["Follow"] and uid(object) == uid(current_user) and
         e(activity, :subject, :profile, nil) do
      e(activity, :subject, nil)
    else
      object
    end
  end

  def preloads(),
    do: [
      :character,
      profile: [:icon]
    ]
end
