defmodule Bonfire.Web.Views.PublicPagesCacheTest do
  use Bonfire.UI.Me.ConnCase, async: false

  @public_pages ["/about", "/conduct", "/privacy", "/impressum"]

  test "logged-in public pages are interactive and never publicly cacheable" do
    account = fake_account!()
    user = fake_user!(account)

    for path <- @public_pages do
      conn =
        [user: user, account: account]
        |> conn()
        |> get(path)

      assert get_resp_header(conn, "cache-control") == ["private, no-store"]
      assert conn.resp_body =~ "bonfire_live"
      refute conn.resp_body =~ ~s(data-live-socket="false")
    end
  end

  test "CacheControlPlug detects authentication from the session before user assigns exist" do
    conn =
      conn(user: "session-user-id", account: "session-account-id")
      |> Bonfire.UI.Common.CacheControlPlug.call(purgeable: false)

    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
    assert conn.private[:plug_session_info] != nil
  end
end
