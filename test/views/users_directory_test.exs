defmodule Bonfire.UI.Me.UsersDirectoryTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  use Bonfire.Common.Config
  alias Bonfire.Me.Fake

  describe "guest pagination on the users directory (without JavaScript)" do
    setup do
      # Make the directory visible to guests
      original_show_to = Config.get([Bonfire.UI.Me.UsersDirectoryLive, :show_to])
      Config.put([Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

      on_exit(fn ->
        Config.put([Bonfire.UI.Me.UsersDirectoryLive, :show_to], original_show_to)
      end)

      limit = Bonfire.Common.Config.get(:default_pagination_limit, 2)

      # More than one page worth of users. The directory is reverse
      # chronological, so the highest-numbered user is newest (first page).
      total = limit * 2 + 1

      for n <- 1..total do
        Fake.fake_user!("directory user #{n}")
      end

      %{limit: limit, total: total}
    end

    test "clicking 'Next page' as a guest shows the next users, not a blank page", %{
      limit: limit,
      total: total
    } do
      conn()
      |> visit("/users")
      # The first page lists a page worth of users, newest first
      |> assert_has("[data-id=profile_name]", count: limit)
      |> assert_has("[data-id=profile_name]", text: "directory user #{total}")
      # The no-JS guest fallback link must be present (this is the bug: it isn't)
      |> assert_has("a[data-id=next_page]", text: "Next page")
      # Following it must show the NEXT users, not a blank page nor the same ones
      |> click_link("a[data-id=next_page]", "Next page")
      |> assert_has("[data-id=profile_name]")
      |> refute_has("[data-id=profile_name]", text: "directory user #{total}")
      |> assert_has("[data-id=profile_name]", text: "directory user #{total - limit}")
    end
  end
end
