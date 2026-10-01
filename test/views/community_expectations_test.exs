defmodule Bonfire.Web.Views.CommunityExpectationsTest do
  use Bonfire.UI.Me.ConnCase, async: false

  test "about explains sharing and experience without appearance settings" do
    conn()
    |> visit("/about")
    |> assert_has("#community-expectations h2", text: "How this community works")
    |> assert_has("#community-sharing-title", text: "Sharing a post")
    |> assert_has("#community-connections-title", text: "Connecting with other communities")
    |> assert_has("#community-experience-title", text: "Your home feed")
    |> assert_has("#community-sharing", text: "Specify your default boundary when publishing a new activity")
    |> assert_has("#community-visibility", text: "DO NOT make new users easily discoverable")
    |> assert_has("details#community-all-defaults:not([open])")
    |> refute_has("#community-expectations", text: "Customise the look and feel")
    |> refute_has("#community-expectations", text: "Default avatars")
  end

  test "directory visibility uses the existing setting option" do
    Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

    conn()
    |> visit("/about")
    |> assert_has("#community-directory", text: "Guests")
  end

  test "feed defaults use the singular keys used by preference controls" do
    Process.put([:bonfire_social, Bonfire.Social.Feeds, :include, :boost], false)
    Process.put([:bonfire_social, Bonfire.Social.Feeds, :include, :follow], false)

    defaults = Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive.feed_defaults()

    assert {:boost, "Boosts", false} in defaults
    assert {:follow, "Follows", false} in defaults
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
