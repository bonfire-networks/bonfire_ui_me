defmodule Bonfire.UI.Me.UserPreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.UI.Me.Integration, only: [is_admin?: 1]
  import Bonfire.Common.Utils
  prop user, :map
  prop go, :string

end
