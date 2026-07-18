defmodule Bonfire.UI.Me.AuthLayoutLive do
  @moduledoc "Shared shell for the auth views (login, signup, remote interaction). Renders the `:two_panels` or minimal layout (per the `[:ui, :auth, :layout]` setting) with branding, tagline, logo and footer, and yields the inner form area via the default slot."
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, default: "auth"
  # width of the inner content column (e.g. wider for the 3-tab remote interaction view)
  prop content_class, :css_class, default: "max-w-md"

  slot default
end
