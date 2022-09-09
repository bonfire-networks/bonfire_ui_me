defmodule Bonfire.UI.Me.WidgetProfileLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop user, :any
  prop widget_title, :string

  def display_url("https://"<>url), do: url
  def display_url("http://"<>url), do: url
  def display_url(url), do: url

end
