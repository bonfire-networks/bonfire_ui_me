defmodule Bonfire.UI.Me.AuthLayoutLive do
  @moduledoc "Shared shell for the auth views. `[:ui, :auth, :layout]` picks `:minimal` (the guest board, default) or `:two_panels`."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "DOM id of the sheet."
  prop id, :string, default: "auth"

  @doc "Which auth page this is, so the masthead leaves out its own action."
  prop page, :atom, default: nil

  @doc "The page's heading. Leave it out when the page renders its own."
  prop title, :string, default: nil

  @doc "`:form` (580px) or `:page` (720px)."
  prop size, :atom, default: :form

  slot default
end
