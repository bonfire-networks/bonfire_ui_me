defmodule Bonfire.UI.Me.UserPreviewLiveTest do
  @moduledoc """
  `UserPreviewLive`'s `:card` variant: by default the name link stretches over the whole card; the hover card turns that off because it holds its own follow button, so only the name and avatar link to the profile.
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Me.UserPreviewLive

  test "by default the name link covers the card and the avatar isn't a separate link" do
    user = fake_user!()
    doc = render_preview(user)

    assert [link] = Floki.find(doc, "a[data-role=user_preview_name]")
    assert Floki.attribute(link, "class") |> hd() =~ "after:inset-0"
    assert Floki.find(doc, "[data-role=user_preview_avatar_link]") == []
  end

  test "with stretch_link off, only the name and the avatar link to the profile" do
    user = fake_user!()
    doc = render_preview(user, stretch_link: false)

    assert [link] = Floki.find(doc, "a[data-role=user_preview_name]")
    refute Floki.attribute(link, "class") |> hd() =~ "after:inset-0"
    assert Floki.attribute(link, "href") == ["/@#{user.character.username}"]

    assert [avatar_link] = Floki.find(doc, "a[data-role=user_preview_avatar_link]")
    assert Floki.attribute(avatar_link, "href") == ["/@#{user.character.username}"]

    # the name link already announces the profile, so the avatar link stays out of the tab order and the a11y tree
    assert Floki.attribute(avatar_link, "tabindex") == ["-1"]
    assert Floki.attribute(avatar_link, "aria-hidden") == ["true"]
  end

  test "without a target, the name and avatar links are LiveView navigation, not full page loads" do
    user = fake_user!()
    doc = render_preview(user, stretch_link: false)

    assert Floki.attribute(doc, "a[data-role=user_preview_name]", "data-phx-link") == ["redirect"]

    assert Floki.attribute(doc, "a[data-role=user_preview_avatar_link]", "data-phx-link") == [
             "redirect"
           ]
  end

  test "with target _blank (the circle embed), the name link stays a plain link opening a new tab" do
    user = fake_user!()
    doc = render_preview(user, target: "_blank")

    assert [link] = Floki.find(doc, "a[data-role=user_preview_name]")
    assert Floki.attribute(link, "data-phx-link") == []
    assert Floki.attribute(link, "target") == ["_blank"]
    assert Floki.attribute(link, "rel") == ["noopener"]
  end

  test "the handle is the full @user@domain, and the bio is plain text" do
    user = fake_user!(%{}, %{summary: "<p>I knit <a href=\"https://example.org\">things</a></p>"})
    doc = render_preview(user, with_summary: true)

    assert text(doc, "[data-role=user_preview_handle]") =~ ~r/^@#{user.character.username}@.+/
    assert text(doc, "[data-role=user_preview_bio]") =~ "I knit things"
    assert Floki.find(doc, "[data-role=user_preview_bio] a") == []
  end

  defp render_preview(user, overrides \\ []) do
    assigns =
      %{
        user: user,
        href: "/@#{user.character.username}",
        parent_id: "user_preview_test",
        __context__: %{}
      }
      |> Map.merge(Map.new(overrides))

    render_component(&UserPreviewLive.render/1, assigns)
    |> Floki.parse_fragment!()
  end

  defp text(doc, selector) do
    doc
    |> Floki.find(selector)
    |> Floki.text()
    |> String.trim()
  end
end
