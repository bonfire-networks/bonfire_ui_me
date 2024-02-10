defmodule Bonfire.UI.Me.ProfileLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :any, default: nil

  prop href, :string, default: nil
  prop icon, :any, default: nil
  prop text, :string, default: nil

  def display_url("https://" <> url), do: url
  def display_url("http://" <> url), do: url
  def display_url(url), do: url

  def render(%{icon: nil, href: href} = assigns) do
    assigns
    |> assign(
      :icon,
      (URI.parse(href).host || "")
      |> String.replace("www.", "")
      |> debug("hooost")
      |> maybe_icon()
    )
    |> render_sface()
  end

  def maybe_icon("youtu" <> _), do: "ri:youtube-fill"
  def maybe_icon("orcid" <> _), do: "simple-icons:orcid"
  def maybe_icon("git" <> _), do: "mdi:git"
  def maybe_icon("instagram" <> _), do: "ri:instagram-line"
  def maybe_icon(_), do: nil
end
