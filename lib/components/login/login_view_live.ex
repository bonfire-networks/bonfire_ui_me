defmodule Bonfire.UI.Me.LoginViewLive do
  use Bonfire.UI.Common.Web, :stateless_component
  prop form, :any
  prop error, :any
  prop go, :any, default: nil
  prop passwordless_only?, :boolean, default: false
  prop sso_first?, :boolean, default: false
  prop external_signup_url, :string, default: nil
  prop gated_login_message, :string, default: nil

  @doc "Whether a login attempt just failed, so folded login forms open themselves and the error is visible."
  def login_error?(error, form),
    do: !!(error || e(form, :source, :errors, :form, nil) || e(form, :errors, :form, nil))

  @doc "The email to put back in the field after a failed login, so the person doesn't retype it."
  def attempted_email(%{params: %{"email_or_username" => email}}) when is_binary(email), do: email
  def attempted_email(_), do: nil
end
