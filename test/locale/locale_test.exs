

defmodule Bonfire.UI.Me.LocaleTest do
  use Bonfire.UI.Me.ConnCase, async: true
  # alias Bonfire.Social.Fake
  import Phoenix.LiveViewTest
  alias Bonfire.Common.Localise
  alias Cldr.Plug.SetLocale
  alias Plug.Conn

  test "locale is detected from accept header" do
    conn()
    |> Conn.put_req_header("accept-language", "es_MX, es, en-gb;q=0.8, en;q=0.7")
    |> SetLocale.call(Localise.set_locale_config())

    assert "es-MX" == Localise.get_locale().canonical_locale_name
  end

  test "valid locale is detected" do
    conn()
    |> Conn.put_req_header("accept-language", "xyz, es;q=0.8")
    |> SetLocale.call(Localise.set_locale_config())

    assert "es" == Localise.get_locale().canonical_locale_name
  end

  @tag :fixme
  test "locale falls back to default" do
    conn()
    |> Conn.put_req_header("accept-language", "xyz, abc;q=0.8")
    |> SetLocale.call(Localise.set_locale_config())

    assert "en" == Localise.get_locale().canonical_locale_name
  end

  @tag :fixme
  test "locale in query string takes precedence" do
    build_conn(:get, "/?locale=es", nil)
    |> Conn.put_req_header("accept-language", "fr")
    |> Conn.fetch_query_params()
    |> Conn.fetch_session()
    |> SetLocale.call(Localise.set_locale_config())

    assert "es" == Localise.get_locale()
  end

end
