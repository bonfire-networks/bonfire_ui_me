defmodule Bonfire.UI.Me.WidgetProfileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :any, default: nil
  prop widget_title, :string, default: nil
end
