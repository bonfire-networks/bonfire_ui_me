defmodule Bonfire.UI.Me.ProfileNavLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :map
  prop selected_tab, :any, default: nil
  prop path, :string, default: "@"

end
