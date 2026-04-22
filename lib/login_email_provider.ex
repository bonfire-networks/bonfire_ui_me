defmodule Bonfire.UI.Me.LoginEmailProvider do
  @moduledoc """
  Behaviour for extensions that can recognise a login email from an external source and bootstrap a local Bonfire account+user for it.

  Implement this behaviour and declare `@behaviour Bonfire.UI.Me.LoginEmailProvider` in your module — it will be auto-discovered at startup via
  `Bonfire.Common.ExtensionBehaviour`.

  Called from `Bonfire.UI.Me.ForgotPasswordController.create/2` via `ensure/1` when `Accounts.get_by_email/1` returns `nil`. First `:ok` wins; otherwise the controller falls through to the standard neutral response and no link is sent.

  Providers must NEVER raise or leak membership status to callers — the outer flow is deliberately neutral to avoid becoming an email-existence oracle.
  """
  @behaviour Bonfire.Common.ExtensionBehaviour
  use Bonfire.Common.Utils, only: []
  import Untangle

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

  def app_modules(), do: Bonfire.Common.ExtensionBehaviour.behaviour_app_modules(__MODULE__)

  @spec modules() :: [atom]
  def modules(), do: Bonfire.Common.ExtensionBehaviour.behaviour_modules(__MODULE__)

  @doc """
  Iterates all discovered providers for `email`, returning on the first
  `:ok`. Returns `:no_match` if every provider declines or errors.
  """
  @spec ensure(String.t()) :: {:ok, term()} | :no_match
  def ensure(email), do: ensure(modules(), email)

  @doc false
  @spec ensure([module()], String.t()) :: {:ok, term()} | :no_match
  def ensure(providers, email) when is_list(providers) and is_binary(email) and email != "" do
    Enum.reduce_while(providers, :no_match, fn provider, acc ->
      case safe_call(provider, email) do
        {:ok, _} = ok -> {:halt, ok}
        :no_match -> {:cont, acc}
        {:error, reason} -> {:cont, log_and_continue(provider, reason, acc)}
      end
    end)
  end

  def ensure(_, _), do: :no_match

  defp safe_call(provider, email) do
    provider.ensure_account(email)
  rescue
    e ->
      error(e, "login email provider #{inspect(provider)} raised — treating as :no_match")
      {:error, e}
  end

  defp log_and_continue(provider, reason, acc) do
    warn(reason, "login email provider #{inspect(provider)} returned an error")
    acc
  end
end
