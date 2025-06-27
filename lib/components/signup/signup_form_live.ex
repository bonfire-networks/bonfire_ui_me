defmodule Bonfire.UI.Me.SignupFormLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any
  prop invite, :any
  prop auth_second_factor_secret, :any, default: nil

  defp prepare_error(e) when is_binary(e) do
    e
  end

  defp prepare_error({e, _}) when is_binary(e) do
    e
  end

  defp prepare_error({:error, e}) when is_binary(e) do
    e
  end

  defp prepare_error(nil) do
    nil
  end

  defp prepare_error(e) do
    inspect(e)
  end
end
