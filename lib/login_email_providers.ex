defmodule Bonfire.UI.Me.LoginEmailProviders do
  @moduledoc """
  Runs the configured `Bonfire.UI.Me.LoginEmailProvider` implementations
  in order. First `:ok` wins; `:no_match` and `{:error, _}` are skipped.

  Configure with:

      config :bonfire_ui_me, :login_email_providers, [MyApp.SomeProvider]

  Called from `Bonfire.UI.Me.ForgotPasswordController.create/2` on an
  unknown email so that extensions like `bonfire_ghost` can bootstrap the
  local account before the magic link is requested.
  """
  import Untangle

  @doc """
  Iterates the configured providers for `email`, returning on the first
  `:ok`. Returns `:no_match` if every provider declines or errors.
  """
  @spec ensure(String.t()) :: {:ok, term()} | :no_match
  def ensure(email) when is_binary(email) and email != "" do
    :bonfire_ui_me
    |> Application.get_env(:login_email_providers, [])
    |> Enum.reduce_while(:no_match, fn provider, acc ->
      case safe_call(provider, email) do
        {:ok, _} = ok -> {:halt, ok}
        :no_match -> {:cont, acc}
        {:error, reason} -> {:cont, log_and_continue(provider, email, reason, acc)}
      end
    end)
  end

  def ensure(_), do: :no_match

  defp safe_call(provider, email) do
    provider.ensure_account(email)
  rescue
    e ->
      error(e, "login email provider #{inspect(provider)} raised — treating as :no_match")
      {:error, e}
  end

  defp log_and_continue(provider, _email, reason, acc) do
    warn(reason, "login email provider #{inspect(provider)} returned an error")
    acc
  end
end
