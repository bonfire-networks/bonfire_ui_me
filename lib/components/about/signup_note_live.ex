defmodule Bonfire.UI.Me.SignupNoteLive do
  @moduledoc "The sentence that tells a guest how new accounts are made here, for an instance that has closed open sign-ups. It names the rule that applies: an external sign-up page (such as a Ghost site), sign-ups limited to certain email domains or sign-in services, or invitation only."
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "The note as `{:link, url, text}`, or `{:text, text}` when there is nowhere to send the visitor."
  def note do
    cond do
      url = Bonfire.UI.Me.LoginLive.external_signup_url() ->
        {:link, url, l("New accounts are created on %{site}", site: URI.parse(url).host || url)}

      Bonfire.Me.Accounts.signup_credentials_active?() ->
        {:text, l("New accounts are limited to certain email domains or sign-in services")}

      true ->
        {:text, l("New accounts by invitation only")}
    end
  end
end
