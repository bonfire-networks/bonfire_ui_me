defmodule Bonfire.Me.Dashboard.Test do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  alias Bonfire.Me.Fake

  # TODO

  # describe "show" do

  #   test "not logged in" do
  #     page =
  #       conn()
  #       |> get("/")
  #       |> floki_response()
  #     # todo: assert looks homepagey
  #   end

  #   test "with account" do
  #     account = fake_account!()
  #     user = fake_user!(account)
  #     conn = conn(account: account)
  #     next = "/"
  #     {view, doc} = floki_live(conn, next) #|> IO.inspect
  #     assert [_] = Floki.find(doc, "#account_dashboard")
  #   end

  #   test "with user" do
  #     account = fake_account!()
  #     user = fake_user!(account)
  #     conn = conn(user: user, account: account)
  #     next = "/"
  #     {view, doc} = floki_live(conn, next) #|> IO.inspect
  #     assert [_] = Floki.find(doc, "#user_dashboard")
  #   end

  # end
end
