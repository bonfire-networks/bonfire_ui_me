defmodule Bonfire.UI.Me.EmbedTokenRevocationTest do
  @moduledoc """
  An embed token (what lets an embedded comments widget act as the user) stops working once the account's other sessions are revoked, as on a password or email change or a reset. A token signed after that works again.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.LivePlugs.LoadCurrentUserFromEmbedToken

  setup do
    account = fake_account!()
    user = fake_user!(account)

    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: "a post to comment on"}},
        boundary: "public"
      )

    {:ok, account: account, user: user, post: post}
  end

  # whether the embedded widget recognised the token's user (the reply composer only renders for a signed-in user)
  defp signed_in_via?(post, token) do
    {:ok, view, _html} = live(conn(), "/comments/embed/#{post.id}?bonfire_embed_token=#{token}")
    has_element?(view, "#inline-reply-portal")
  end

  # revokes the account's other sessions, strictly after any token already signed
  defp revoke!(account) do
    Process.sleep(5)
    {:ok, _} = Accounts.revoke_other_sessions(account)
    Process.sleep(5)
  end

  test "a token signed before the sessions were revoked no longer signs the user in", %{
    account: account,
    user: user,
    post: post
  } do
    token = LoadCurrentUserFromEmbedToken.sign(user.id)

    # control: it works before the revocation
    assert signed_in_via?(post, token)

    revoke!(account)

    refute signed_in_via?(post, token)
  end

  # whether a request carrying the token is taken as authenticated by the HTTP-layer plugs (the CSRF one skips its check for it)
  defp valid_token?(token),
    do:
      Plug.Test.conn(:get, "/comments/embed/x?bonfire_embed_token=#{token}")
      |> LoadCurrentUserFromEmbedToken.valid_token?()

  test "a token signed before the sessions were revoked is no longer valid for the HTTP-layer plugs",
       %{account: account, user: user} do
    token = LoadCurrentUserFromEmbedToken.sign(user.id)

    # control: it is valid before the revocation
    assert valid_token?(token)

    revoke!(account)

    refute valid_token?(token)

    # and one signed after is valid again
    assert valid_token?(LoadCurrentUserFromEmbedToken.sign(user.id))
  end

  test "a token signed after the revocation works", %{account: account, user: user, post: post} do
    revoke!(account)

    token = LoadCurrentUserFromEmbedToken.sign(user.id)

    assert signed_in_via?(post, token)
  end
end
