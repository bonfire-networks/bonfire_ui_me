defmodule Bonfire.UI.Me.WidgetForecastLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop location, :string, default: nil
  prop widget_title, :string, default: nil

end
