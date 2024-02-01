defmodule Bonfire.UI.Me.ProfileLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :string,
    required: false,
    default:
      "flex border hover:border-base-content/60 rounded border-base-content/20 px-3 py-2 items-center gap-3"

  prop href, :string, default: ""
  prop icon, :string, required: false
  prop text, :string, default: ""

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url
end
