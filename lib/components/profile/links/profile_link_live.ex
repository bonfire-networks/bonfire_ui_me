defmodule Bonfire.UI.Me.ProfileLinkLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :any, default: nil

  prop href, :string, default: nil
  prop icon, :any, default: nil
  prop text, :string, default: nil

  prop metadata, :any, default: nil

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

  def maybe_icon("git" <> _), do: "mdi:git"
  def maybe_icon("orcid" <> _), do: "simple-icons:orcid"
  def maybe_icon("liberapay" <> _), do: "streamline:blood-donate-drop-solid"
  def maybe_icon("tumblr" <> _), do: "icon-park-solid:tumblr"
  def maybe_icon("reddit" <> _), do: "teenyicons:reddit-solid"
  def maybe_icon("stackoverflow" <> _), do: "tabler:brand-stackoverflow"
  def maybe_icon("youtu" <> _), do: "ri:youtube-fill"
  def maybe_icon("pinterest" <> _), do: "bxl:pinterest"
  def maybe_icon("linkedin" <> _), do: "mdi:linkedin"
  def maybe_icon("twitter" <> _), do: "ph:twitter-logo-thin"
  def maybe_icon("instagram" <> _), do: "ri:instagram-line"
  def maybe_icon(_), do: nil
end
