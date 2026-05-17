defmodule Bonfire.UI.Me.InstancesDirectoryTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  use Bonfire.Common.Config
  alias Bonfire.Federate.ActivityPub.Instances

  describe "guest pagination on the fediverse instances directory (without JavaScript)" do
    setup do
      # The instances directory reuses the users directory `show_to` setting
      original_show_to = Config.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to])
      Config.put([Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

      on_exit(fn ->
        Config.put([Bonfire.UI.Me.UsersDirectoryLive, :show_to], original_show_to)
      end)

      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)

      # More than one page worth of known instances. Listing is `desc(:id)`,
      # so the last-created instance is newest (shown on the first page).
      total = limit * 2 + 1

      for n <- 1..total do
        {:ok, _peer} = Instances.get_or_create("https://dir-instance-#{n}.test/actor")
      end

      %{limit: limit, total: total}
    end

    test "clicking 'Next page' as a guest shows the next instances, not a blank page", %{
      total: total,
      limit: limit
    } do
      conn()
      |> visit("/known_instances")
      # The first page lists the newest known instances
      |> assert_has("a", text: "dir-instance-#{total}.test")
      # The no-JS guest fallback link must be present (this is the bug: it isn't)
      |> assert_has("a[data-id=next_page]", text: "Next page")
      # Following it must show the NEXT instances, not a blank page nor the same ones
      |> click_link("a[data-id=next_page]", "Next page")
      |> refute_has("a", text: "dir-instance-#{total}.test")
      |> assert_has("a", text: "dir-instance-#{total - limit}.test")
    end
  end
end
