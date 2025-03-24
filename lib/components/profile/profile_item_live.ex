defmodule Bonfire.UI.Me.ProfileItemLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop profile, :any
  prop lg, :boolean, default: false
  prop is_remote?, :boolean, default: nil

  prop wrapper_class, :css_class, default: nil

  prop character, :any
  prop class, :css_class
  prop show_controls, :list, default: [:follow]
  prop activity_id, :any, default: nil
  prop inline, :boolean, default: false
  prop show_summary, :boolean, default: false
  prop with_popover, :boolean, default: false
  prop avatar_class, :css_class, default: nil
  prop only_img, :boolean, default: false

  prop parent_id, :any, default: nil

  slot default, required: false
end
