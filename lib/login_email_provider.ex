defmodule Bonfire.UI.Me.LoginEmailProvider do
  @moduledoc """
  Behaviour for extensions that can recognise a login email from an
  external source and bootstrap a local Bonfire account+user for it.

  Used by `Bonfire.UI.Me.LoginEmailProviders.ensure/1` during the
  passwordless login submit path (`ForgotPasswordController.create/2`) —
  when `Accounts.get_by_email/1` returns `nil`, the controller iterates
  the modules configured under `config :bonfire_ui_me, :login_email_providers`
  and asks each one whether it can provision the email. First `:ok` wins;
  otherwise the controller falls through to the standard neutral response
  and no link is sent.

  Providers must NEVER raise or leak membership status to callers — the
  outer flow is deliberately neutral to avoid becoming an email-existence
  oracle.
  """

  @doc """
  Attempts to provision a local account+user for `email` from an external
  source.

  Return values:

    * `{:ok, term()}` — provisioned (or already present). The caller
      re-fetches the local account and proceeds with sending the magic
      link.
    * `:no_match` — this provider does not recognise `email`. Caller
      should try the next provider.
    * `{:error, term()}` — upstream failure. Caller logs and tries the
      next provider; the error is never surfaced to the end user.
  """
  @callback ensure_account(email :: String.t()) ::
              {:ok, term()} | :no_match | {:error, term()}
end
