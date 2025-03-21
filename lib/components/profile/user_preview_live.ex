defmodule Bonfire.UI.Me.UserPreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Utils
  # import Bonfire.Common.Media

  prop user, :map
  prop href, :string, default: nil
  prop path_prefix, :string, default: "/@"
  prop go, :string, default: nil
  prop with_banner, :boolean, default: false
  prop with_summary, :boolean, default: false
  prop is_local, :boolean, required: false, default: true
  prop class, :css_class, default: ""

  prop parent_id, :any, default: nil

  slot actions, required: false
end
