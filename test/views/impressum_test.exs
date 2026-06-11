defmodule Bonfire.Web.Views.ImpressumTest do
  use Bonfire.UI.Me.ConnCase, async: false

  # `?cache=skip` bypasses the static disk cache (MaybeStaticGeneratorPlug) so we
  # exercise the dynamic LiveView render — the same render the static generator
  # caches for guests in production.
  test "guest can load /impressum when impressum is empty" do
    Bonfire.Common.Config.put([:terms, :impressum], nil)
    conn = conn()

    {:ok, _view, html} = live(conn, "/impressum?cache=skip")
    assert html =~ "impressum"
  end

  test "guest can load /impressum when impressum has content" do
    Bonfire.Common.Config.put([:terms, :impressum], "Some legal notice here")
    conn = conn()

    {:ok, _view, html} = live(conn, "/impressum?cache=skip")
    assert html =~ "Some legal notice here"
  end

  test "logged-in user can load /impressum when impressum is empty" do
    Bonfire.Common.Config.put([:terms, :impressum], nil)
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    {:ok, _view, html} = live(conn, "/impressum")
    assert html =~ "impressum"
  end

  test "logged-in user can load /impressum when impressum has content" do
    Bonfire.Common.Config.put([:terms, :impressum], "Some legal notice here")
    account = fake_account!()
    user = fake_user!(account)
    conn = conn(user: user, account: account)

    {:ok, _view, html} = live(conn, "/impressum")
    assert html =~ "Some legal notice here"
  end
end
