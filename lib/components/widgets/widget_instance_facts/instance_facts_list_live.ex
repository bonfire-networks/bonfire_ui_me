defmodule Bonfire.UI.Me.InstanceFactsListLive do
  @moduledoc "The facts people compare servers on (federation, discoverability, guest access), each with an icon."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Adds the notes for guests; by default, when nobody is signed in."
  prop is_guest?, :any, default: nil

  @doc "The list's DOM id, unique per page."
  prop list_id, :string, default: "about-meta"
end
