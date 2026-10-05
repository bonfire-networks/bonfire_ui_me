defmodule Bonfire.Web.Views.CommunityExpectationsTest do
  use Bonfire.UI.Me.ConnCase, async: false

  test "about shows community defaults without feed or appearance settings" do
    conn()
    |> visit("/about")
    |> assert_has("#community-expectations h2", text: "How this community works")
    |> assert_has("#community-sharing-title", text: "Sharing a post")
    |> assert_has("#community-expectations > section:first-of-type#community-connections",
      text: "Connecting with other communities"
    )
    |> refute_has("#community-experience")
    |> refute_has("#community-expectations", text: "Your home feed")
    |> assert_has("#community-sharing",
      text: "Specify your default boundary when publishing a new activity"
    )
    |> assert_has("#community-visibility", text: "DO NOT make new users easily discoverable")
    |> assert_has("section#community-all-defaults h3", text: "All community defaults")
    |> assert_has("#community-all-defaults #community-report-forwarding")
    |> assert_has("#community-all-defaults #community-media")
    |> assert_has("#community-all-defaults #community-interface-language")
    |> refute_has("#community-all-defaults summary")
    |> refute_has("details#community-all-defaults")
    |> refute_has("#community-expectations", text: "Customise the look and feel")
    |> refute_has("#community-expectations", text: "Default avatars")
  end

  test "Archipelago shows allowed destinations as linked cards" do
    summary = Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive
    Repatch.patch(summary, :federation_mode, [mode: :shared], fn -> :allowlist_only end)

    Repatch.patch(summary, :instance_allowlist, [mode: :shared], fn ->
      {[%{subject: %{named: %{name: "community.example.org"}}}], 1}
    end)

    conn()
    |> visit("/about")
    |> assert_has("#community-federation", text: "Archipelago")
    |> assert_has("#community-connections", text: "explicitly allowed communities and people")
    |> assert_has("#community-allowlist a[href='https://community.example.org'][target='_blank']",
      text: "community.example.org"
    )
  end

  test "Archipelago explains an empty allowlist" do
    summary = Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive
    Repatch.patch(summary, :federation_mode, [mode: :shared], fn -> :allowlist_only end)
    Repatch.patch(summary, :instance_allowlist, [mode: :shared], fn -> {[], 0} end)

    conn()
    |> visit("/about")
    |> assert_has("#community-connections", text: "No communities or people are listed yet.")
    |> refute_has("#community-allowlist")
  end

  test "directory visibility uses the existing setting option" do
    Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

    conn()
    |> visit("/about")
    |> assert_has("#community-directory", text: "Guests")
  end

  test "privacy and safety defaults describe opt-outs and remote report forwarding" do
    Process.put([:bonfire_me, Bonfire.Me.Users, :undiscoverable], true)
    Process.put([:bonfire_search, Bonfire.Search.Indexer, :modularity], :disabled)
    Process.put([:bonfire_social, Bonfire.Social.Flags, :forward_by_default], true)
    Process.put([:bonfire_ui_social, Bonfire.UI.Social.Activity.MediaLive, :hide], true)

    conn()
    |> visit("/about")
    |> assert_has("#community-discoverability", text: "Enabled")
    |> assert_has("#community-indexing", text: "Enabled")
    |> assert_has("#community-report-forwarding", text: "Enabled")
    |> assert_has("#community-media", text: "Enabled")
  end
end
