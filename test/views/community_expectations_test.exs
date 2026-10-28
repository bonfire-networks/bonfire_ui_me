defmodule Bonfire.Web.Views.CommunityExpectationsTest do
  use Bonfire.UI.Me.ConnCase, async: false

  doctest Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive

  test "about shows the defaults as rows, five first and the rest behind Show all" do
    conn()
    |> visit("/about")
    |> assert_has("#community-settings h2", text: "How this community works")
    |> assert_has("#community-settings [data-role=settings-rows] > li:first-child",
      text: "Default audience"
    )
    |> assert_has("#community-settings #community-post-audience")
    |> assert_has("#community-settings #community-report-forwarding")
    |> assert_has("#community-settings #community-interface-language")
    # the toggle is a checkbox and label, so it works on static guest pages
    |> assert_has("#community-settings input#community-settings-all[type=checkbox]")
    |> assert_has("#community-settings label[for=community-settings-all]", text: "Show all")
    # one list replaces the old sentences plus table, and the settings' negated wording is gone
    |> refute_has("#community-expectations details")
    |> refute_has("#community-expectations", text: "DO NOT")
    |> refute_has("#community-expectations", text: "Customise the look and feel")
  end

  test "the meta line says how the community connects and whether it shows up in search" do
    summary = Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive
    Repatch.patch(summary, :federation_mode, [mode: :shared], fn -> true end)
    Process.put([:bonfire_search, Bonfire.Search.Indexer, :modularity], :disabled)

    conn()
    |> visit("/about")
    # the two facts, plus the guest note since this visitor isn't signed in
    |> assert_has("#about-meta li", count: 3)
    |> assert_has("#about-meta", text: "Connected to the fediverse")
    |> assert_has("#about-meta", text: "Hidden from search engines")
    |> assert_has("#about-meta #about-guest-info")
    |> assert_has("#community-federation", text: "The whole fediverse")
  end

  test "Archipelago lists the allowed communities in the Connects to row" do
    summary = Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive
    Repatch.patch(summary, :federation_mode, [mode: :shared], fn -> :allowlist_only end)

    Repatch.patch(summary, :instance_allowlist, [mode: :shared], fn ->
      {[%{subject: %{named: %{name: "community.example.org"}}}], 1}
    end)

    conn()
    |> visit("/about")
    |> assert_has("#about-meta", text: "Connected to selected communities")
    |> assert_has(
      "#community-federation #community-allowlist a[href='https://community.example.org'][target='_blank']",
      text: "community.example.org"
    )
  end

  test "Archipelago says so when no communities are allowed yet" do
    summary = Bonfire.UI.Me.SettingsViewsLive.InstanceSummaryLive
    Repatch.patch(summary, :federation_mode, [mode: :shared], fn -> :allowlist_only end)
    Repatch.patch(summary, :instance_allowlist, [mode: :shared], fn -> {[], 0} end)

    conn()
    |> visit("/about")
    |> assert_has("#community-federation", text: "No communities yet")
    |> refute_has("#community-allowlist")
  end

  test "directory visibility uses the existing setting option" do
    Process.put([:bonfire_ui_me, Bonfire.UI.Me.UsersDirectoryLive, :show_to], :guests)

    conn()
    |> visit("/about")
    |> assert_has("#community-directory", text: "Anyone")
  end

  test "privacy and safety defaults read as what a visitor would see" do
    Process.put([:bonfire_me, Bonfire.Me.Users, :undiscoverable], true)
    Process.put([:bonfire_search, Bonfire.Search.Indexer, :modularity], :disabled)
    Process.put([:bonfire_social, Bonfire.Social.Flags, :forward_by_default], true)
    Process.put([:bonfire_ui_social, Bonfire.UI.Social.Activity.MediaLive, :hide], true)

    conn()
    |> visit("/about")
    # undiscoverable and an off indexer both read as Hidden, not as a double negative
    |> assert_has("#community-discoverability", text: "Hidden")
    |> assert_has("#community-indexing", text: "Hidden")
    |> assert_has("#community-report-forwarding", text: "Also sent to their server")
    |> assert_has("#community-media", text: "Blurred")
  end

  test "remote reports and media read as the default when those settings are off" do
    Process.put([:bonfire_social, Bonfire.Social.Flags, :forward_by_default], false)
    Process.put([:bonfire_ui_social, Bonfire.UI.Social.Activity.MediaLive, :hide], false)

    conn()
    |> visit("/about")
    |> assert_has("#community-report-forwarding", text: "Stay with our moderators")
    |> assert_has("#community-media", text: "Not blurred")
  end
end
