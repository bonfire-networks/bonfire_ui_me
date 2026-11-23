defmodule Bonfire.UI.Me.InviteRequestLive do
  @moduledoc "How a guest gets in touch with an instance that has closed open sign-ups: a button that sends them to the external sign-up page if there is one (such as a Ghost site, where accounts come from), or else writes to the instance's contact address (nothing when it has set neither), and beside it the button to message the moderators, for someone on another server who has no account here. `class` shapes both buttons and `wrapper_class` the row they sit in."
  use Bonfire.UI.Common.Web, :stateless_component

  prop id, :string, default: "about-request-invite"
  prop class, :css_class, default: "px-5"
  prop wrapper_class, :css_class, default: "flex flex-wrap items-center gap-3"

  @doc "The address set for invite requests, if any."
  def email, do: Config.get([:ui, :theme, :instance_welcome, :invite_contact_email], nil)

  @doc "Whether the instance has a way to get an account: an external sign-up page, or an address for invite requests."
  def contact?, do: not is_nil(action())

  @doc "The mail link that writes to `email`."
  def href(email), do: "mailto:#{email}?subject=#{URI.encode(l("Invite request"))}"

  @doc "The button's `{link, label}`, or nil when the instance has set neither an external sign-up page nor a contact address."
  def action do
    cond do
      url = Bonfire.UI.Me.LoginLive.external_signup_url() -> {url, l("Sign up")}
      email() not in [nil, ""] -> {href(email()), l("Request an invite")}
      true -> nil
    end
  end
end
