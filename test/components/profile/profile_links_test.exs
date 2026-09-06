defmodule Bonfire.UI.Me.ProfileLinksTest do
  use Bonfire.UI.Me.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Bonfire.UI.Me.ProfileLinksLive

  doctest ProfileLinksLive

  test "missing and blank websites render no section" do
    for website <- [nil, "", " \n "] do
      html = render_component(&ProfileLinksLive.render/1, user: %{profile: %{website: website}}, aliases: [])
      refute html =~ "profile-links"
      refute html =~ "Also on"
    end
  end

  test "website-only profiles show the destination without an account heading" do
    url = Faker.Internet.url()
    html = render_component(&ProfileLinksLive.render/1, user: %{profile: %{website: url}}, aliases: [])
    assert html =~ "profile-websites"
    assert html =~ url
    refute html =~ "profile-also-on"
    refute html =~ "render_error"
  end

  test "external aliases show their label and URL without an empty account section" do
    url = "https://example.org/research"
    aliases = [%{edge: %{object: %{media_type: "website", path: url, metadata: %{"name" => "Research", "verified" => true}}}}]
    html = render_component(&ProfileLinksLive.render/1, user: %{profile: %{website: nil}}, aliases: aliases)
    assert html =~ "Research"
    assert html =~ "example.org/research"
    assert html =~ "Verified link"
    refute html =~ "profile-also-on"
    refute html =~ "render_error"
  end

  test "blank aliases do not leave a wrapper" do
    aliases = [%{edge: %{object: %{media_type: "website", path: " ", metadata: %{}}}}]
    html = render_component(&ProfileLinksLive.render/1, user: nil, aliases: aliases)
    refute html =~ "profile-links"
  end

  test "accounts and websites are separated while preserving their order" do
    account = %{id: "account", profile: %{name: "Name"}, character: %{id: "character", username: "name@example.org"}}
    aliases = [
      %{edge: %{object: account}},
      %{edge: %{object: %{media_type: "website", path: " ", metadata: %{"url" => "https://example.org", "name" => "Website"}}}}
    ]
    assert {[%{href: "https://example.org", label: "Website"}], [^account]} = ProfileLinksLive.group_links(nil, aliases)
    assert {[], [^account]} = ProfileLinksLive.group_links(nil, Enum.take(aliases, 1))
  end
end
