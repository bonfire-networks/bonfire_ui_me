defmodule Bonfire.UI.Me.LoginEmailProvidersTest do
  use Bonfire.UI.Me.DataCase, async: false

  alias Bonfire.UI.Me.LoginEmailProviders

  # Mock providers used across the tests below. They must be defined at the top
  # of the module (not inside `test` blocks) so the atom is registered and the
  # module is loaded before the test process calls them.

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

  setup do
    original = Application.get_env(:bonfire_ui_me, :login_email_providers, [])
    on_exit(fn -> Application.put_env(:bonfire_ui_me, :login_email_providers, original) end)
    :ok
  end

  defp configure(providers),
    do: Application.put_env(:bonfire_ui_me, :login_email_providers, providers)

  test "returns :no_match when no providers are configured" do
    configure([])
    assert :no_match = LoginEmailProviders.ensure("someone@example.com")
  end

  test "returns :no_match for empty or non-binary emails" do
    configure([OkProvider])
    assert :no_match = LoginEmailProviders.ensure("")
    assert :no_match = LoginEmailProviders.ensure(nil)
  end

  test "returns the first :ok result and short-circuits" do
    configure([OkProvider, RaisingProvider])
    assert {:ok, :from_ok_provider} = LoginEmailProviders.ensure("someone@example.com")
  end

  test "skips :no_match providers and tries the next one" do
    configure([NoMatchProvider, OkProvider])
    assert {:ok, :from_ok_provider} = LoginEmailProviders.ensure("someone@example.com")
  end

  test "skips error-returning providers and continues" do
    configure([ErrorProvider, OkProvider])
    assert {:ok, :from_ok_provider} = LoginEmailProviders.ensure("someone@example.com")
  end

  test "treats raising providers as :no_match and continues" do
    configure([RaisingProvider, OkProvider])
    assert {:ok, :from_ok_provider} = LoginEmailProviders.ensure("someone@example.com")
  end

  test "returns :no_match when every provider declines" do
    configure([NoMatchProvider, ErrorProvider, RaisingProvider])
    assert :no_match = LoginEmailProviders.ensure("someone@example.com")
  end
end
