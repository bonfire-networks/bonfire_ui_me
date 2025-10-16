defmodule Bonfire.UI.Me.LocaleTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  # alias Bonfire.Social.Fake
  import Phoenix.LiveViewTest
  alias Bonfire.Common.Localise
  alias Cldr.Plug.SetLocale
  alias Plug.Conn

  test "locale is detected from accept header" do
    conn =
      conn()
      |> Conn.put_req_header(
        "accept-language",
        "es_MX, es, en-gb;q=0.8, en;q=0.7"
      )
      |> Plug.Test.init_test_session(%{})
      |> Conn.fetch_query_params()
      |> Conn.fetch_session()
      |> SetLocale.call(Localise.set_locale_config())

    # Read the locale from the connection's private data
    detected_locale = conn.private[:cldr_locale]
    assert "es-MX" == detected_locale.canonical_locale_name
  end

  test "valid locale is detected" do
    conn =
      conn()
      |> Conn.put_req_header("accept-language", "xyz, es;q=0.8")
      |> Plug.Test.init_test_session(%{})
      |> Conn.fetch_query_params()
      |> Conn.fetch_session()
      |> SetLocale.call(Localise.set_locale_config())

    # Read the locale from the connection's private data
    detected_locale = conn.private[:cldr_locale]
    assert "es" == detected_locale.canonical_locale_name
  end

  # Test that when no locale information is provided, it falls back to the default
  # This test fails because Cldr.Plug.SetLocale seems to pass the default locale as a string ("en")
  test "locale falls back to default when no locale is provided" do
    # Create a basic connection with no locale information
    conn()
    |> Plug.Test.init_test_session(%{})
    |> Conn.fetch_query_params()
    |> Conn.fetch_session()
    # Call the SetLocale plug with the application's config
    |> SetLocale.call(Localise.set_locale_config())

    # Assert that the locale was set to the default ("en")
    assert "en" == Localise.get_locale().canonical_locale_name
  end

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

    # Read the locale from the connection's private data
    detected_locale = conn.private[:cldr_locale]
    assert "es" == detected_locale.canonical_locale_name
  end
end
