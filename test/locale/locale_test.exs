defmodule Bonfire.UI.Me.LocaleTest do
  use Bonfire.UI.Me.ConnCase, async: true
  # alias Bonfire.Social.Fake
  import Phoenix.LiveViewTest
  alias Bonfire.Common.Localise
  alias Cldr.Plug.SetLocale
  alias Plug.Conn

  @tag :fixme
  test "locale is detected from accept header" do
    conn()
    |> Conn.put_req_header(
      "accept-language",
      "es_MX, es, en-gb;q=0.8, en;q=0.7"
    )
    |> SetLocale.call(Localise.set_locale_config())

    assert "es-MX" == Localise.get_locale().canonical_locale_name
  end

  @tag :fixme
  test "valid locale is detected" do
    conn()
    |> Conn.put_req_header("accept-language", "xyz, es;q=0.8")
    |> SetLocale.call(Localise.set_locale_config())

    assert "es" == Localise.get_locale().canonical_locale_name
  end

  # Test that when no locale information is provided, it falls back to the default
  @tag :todo # This test fails because Cldr.Plug.SetLocale seems to pass the default locale as a string ("en")
             # instead of a %Cldr.LanguageTag{} when called directly in tests, causing a FunctionClauseError
             # in Cldr.Plug.PutLocale.put_locale/3. The underlying fallback logic might still work correctly
             # in a full request cycle.
  test "locale falls back to default when no locale is provided" do
    # Create a basic connection with no locale information
    conn()
    # Call the SetLocale plug with the application's config
    |> SetLocale.call(Localise.set_locale_config())

    # Assert that the locale was set to the default ("en")
    # Assert that the locale was set to the default ("en")
    # FIXME: This still fails due to Cldr.Plug.PutLocale passing "en" string instead of LanguageTag
    assert "en" == Localise.get_locale().canonical_locale_name
  end

  @tag :todo
  test "locale in query string takes precedence" do
    # Use Plug.Test.conn to simulate a request with query params
    conn = Plug.Test.conn(:get, "/?locale=es")
    # Add headers and ensure session is initialized (ConnCase might do this, but being explicit)
    conn =
      conn
      |> Plug.Conn.put_req_header("accept-language", "fr")
      |> Plug.Test.init_test_session(%{})

    # Fetch params and session *before* calling the plug
    conn =
      conn
      |> Conn.fetch_query_params()
      |> Conn.fetch_session()

    # Call the SetLocale plug
    conn = SetLocale.call(conn, Localise.set_locale_config())

    # Assert the locale was set correctly from the query param
    assert "es" == Localise.get_locale(conn).canonical_locale_name
  end
end
