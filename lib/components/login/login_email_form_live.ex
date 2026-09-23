defmodule Bonfire.UI.Me.LoginEmailFormLive do
  @moduledoc "The passwordless login: the email sign-in-link form, plus the \"I have a password\" disclosure. Shown on its own on passwordless instances, and behind \"Use email instead\" when the login leads with sign-in services."
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any
  prop go, :any, default: nil
  prop external_signup_url, :string, default: nil
  prop gated_login_message, :string, default: nil
end
