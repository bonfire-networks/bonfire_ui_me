defmodule Bonfire.UI.Me.WidgetProfileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :any, default: nil
  prop widget_title, :string, default: nil

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url
end
