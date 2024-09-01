defmodule Bonfire.UI.Me.HeroMoreActionsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # import Bonfire.UI.Me

  prop user, :map
  prop character_type, :atom, default: nil
  prop permalink, :string, default: nil
  prop boundary_preset, :any, default: nil
  prop silenced_instance_wide?, :boolean, default: false
  prop ghosted_instance_wide?, :boolean, default: false
  prop ghosted?, :boolean, default: false
  prop silenced?, :boolean, default: false

  # defp set_clone_context({_, o}) do
  #   [{:clone_context, o}]
  # end

  # defp set_clone_context(%{id: id}) do
  #   [{:clone_context, id}]
  # end

  # defp set_clone_context(other) do
  #   warn(other, "cannot clone_context, expected a tuple or a map with an ID")
  #   []
  # end
end
