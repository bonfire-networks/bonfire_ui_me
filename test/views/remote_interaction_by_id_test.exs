defmodule Bonfire.UI.Me.RemoteInteractionByIdTest do
  @moduledoc """
  The remote interaction page opened with the id of what to interact with, rather than its address: what a link built without the object gives it (the comments embed, a restricted page, a button clicked while signed out). The page looks the object up, once, when it is opened, and works out the address another instance is to fetch.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  import Phoenix.LiveViewTest

  setup do
    # someone from another instance can only use their account there if this one federates
    Process.put(:federating, true)
    :ok
  end

  test "fills in the address of what the id names" do
    post =
      Bonfire.Posts.Fake.fake_post!(fake_user!(), "public", %{
        post_content: %{html_body: "<p>public</p>"}
      })

    {:ok, _view, html} = live(conn(), "/remote_interaction?type=reply&id=#{post.id}")

    assert html =~ ~s(value="#{Bonfire.Common.URIs.canonical_url(post, preload_if_needed: true)}")
  end

  # another server couldn't read it, so an account there could do nothing with it
  test "offers only to sign in here when other servers can't reach what the id names" do
    post =
      Bonfire.Posts.Fake.fake_post!(fake_user!(), "local", %{
        post_content: %{html_body: "<p>local only</p>"}
      })

    # the positive first: the same page offers the remote form for what other servers can read
    {:ok, _view, html} =
      live(conn(), "/remote_interaction?type=reply&url=https://example.local/x")

    assert html =~ "Interact remotely"

    {:ok, _view, html} = live(conn(), "/remote_interaction?type=reply&id=#{post.id}")

    refute html =~ "Interact remotely"
    refute html =~ Bonfire.Common.URIs.canonical_url(post, preload_if_needed: true)
  end

  # the sign-in and sign-up tabs are on the same page, but its heading is the interaction, not one of them
  test "the page heading names the interaction, not the sign-up tab" do
    {:ok, _view, html} =
      live(conn(), "/remote_interaction?type=message&url=https://example.local/x")

    doc = Floki.parse_document!(html)

    # the positive first: the sign-up tab is on the page
    assert Floki.text(doc) =~ "Sign up"

    assert doc |> Floki.find("[data-role=page-title]") |> Floki.text() |> String.trim() ==
             "Remote interaction"
  end
end
