defmodule Bonfire.UI.Me.LoginEmailProviderTest do
  use Bonfire.UI.Me.DataCase, async: true

  alias Bonfire.UI.Me.LoginEmailProvider

  # Mock providers must be defined at module level so they are compiled and
  # their @behaviour attributes are visible before any test runs.

  defmodule OkProvider do
    @behaviour Bonfire.UI.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: {:ok, :from_ok_provider}
  end

  defmodule NoMatchProvider do
    @behaviour Bonfire.UI.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: :no_match
  end

  defmodule ErrorProvider do
    @behaviour Bonfire.UI.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: {:error, :upstream_down}
  end

  defmodule RaisingProvider do
    @behaviour Bonfire.UI.Me.LoginEmailProvider
    @impl true
    def ensure_account(_email), do: raise("boom")
  end

  test "returns :no_match when no providers are given" do
    assert :no_match = LoginEmailProvider.ensure([], "someone@example.com")
  end

  test "returns :no_match for empty or non-binary emails" do
    assert :no_match = LoginEmailProvider.ensure([OkProvider], "")
    assert :no_match = LoginEmailProvider.ensure([OkProvider], nil)
  end

  test "returns the first :ok result and short-circuits" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([OkProvider, RaisingProvider], "someone@example.com")
  end

  test "skips :no_match providers and tries the next one" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([NoMatchProvider, OkProvider], "someone@example.com")
  end

  test "skips error-returning providers and continues" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([ErrorProvider, OkProvider], "someone@example.com")
  end

  test "treats raising providers as :no_match and continues" do
    assert {:ok, :from_ok_provider} =
             LoginEmailProvider.ensure([RaisingProvider, OkProvider], "someone@example.com")
  end

  test "returns :no_match when every provider declines" do
    assert :no_match =
             LoginEmailProvider.ensure(
               [NoMatchProvider, ErrorProvider, RaisingProvider],
               "someone@example.com"
             )
  end
end
