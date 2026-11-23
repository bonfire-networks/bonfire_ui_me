defmodule Bonfire.UI.Me.AboutIntroLive do
  @moduledoc "The community's name, tagline and description, shared by About and the guest Home."
  use Bonfire.UI.Common.Web, :stateless_component

  prop is_guest?, :boolean, required: true

  @doc "Actions shown under the description in place of the default invite request."
  slot default
end
