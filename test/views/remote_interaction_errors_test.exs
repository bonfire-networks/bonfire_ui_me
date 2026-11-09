defmodule Bonfire.UI.Me.RemoteInteractionErrorsTest do
  @moduledoc """
  When the remote interaction form can't send someone on to their home instance (their address doesn't resolve, the form arrives without it, or a remote instance sends an account we can't find), they come back to a page with the reason, as with the other forms, rather than to a bare 404 with no content type, which mobile browsers offer to download.
  """
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  import Tesla.Mock

  @object "https://example.local/pub/objects/x"
  @form_path "/remote_interaction?" <> URI.encode_query(type: "follow", url: @object)
  @nick_label "Enter your fediverse nick"

  setup do
    # someone from another instance can only use their account there if this one federates
    Process.put(:federating, true)
    :ok
  end

  # the positive first: an address that resolves still goes on to the person's home instance
  test "an address whose instance gives a subscribe address still goes there" do
    mock(fn
      %{method: :get, url: "https://home.local/.well-known/webfinger" <> _} ->
        json(%{
          "subject" => "acct:alice@home.local",
          "links" => [
            %{
              "rel" => "http://ostatus.org/schema/1.0/subscribe",
              "template" => "https://home.local/authorize_interaction?uri={uri}"
            }
          ]
        })

      _ ->
        %Tesla.Env{status: 404, body: ""}
    end)

    conn = post(conn(), "/pub/remote_interaction", form_params("alice@home.local"))

    assert redirected_to(conn) == "https://home.local/authorize_interaction?uri=#{@object}"
  end

  test "an address that doesn't resolve comes back to the form with the reason" do
    mock(fn _ -> %Tesla.Env{status: 404, body: ""} end)

    conn()
    |> visit(@form_path)
    |> fill_in(@nick_label, with: "nobody@unknown.local", exact: false)
    |> click_button("Proceed to follow")
    |> assert_path("/remote_interaction", query_params: %{type: "follow", url: @object})
    |> assert_has("[role=alert]", text: "Couldn't find your account", exact: false)
  end

  test "comes back to the page the form was on, when it was on this instance" do
    mock(fn _ -> %Tesla.Env{status: 404, body: ""} end)

    form_path =
      "/remote_interaction?type=follow&name=Bob&url=#{URI.encode_www_form(@object)}"

    conn = conn()

    conn =
      conn
      |> put_req_header("referer", "http://#{conn.host}#{form_path}")
      |> post("/pub/remote_interaction", form_params("nobody@unknown.local"))

    assert redirected_to(conn) == form_path
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find your account"
  end

  test "doesn't follow a referer from another site" do
    mock(fn _ -> %Tesla.Env{status: 404, body: ""} end)

    conn =
      conn()
      |> put_req_header("referer", "https://elsewhere.local/phish")
      |> post("/pub/remote_interaction", form_params("nobody@unknown.local"))

    assert redirected_to(conn) == @form_path
  end

  test "a form that arrives without an address comes back to the remote interaction page" do
    conn = post(conn(), "/pub/remote_interaction", %{"something" => "else"})

    assert redirected_to(conn) == "/remote_interaction"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
  end

  test "a remote instance sending an account we can't find lands on the remote interaction page" do
    mock(fn _ -> %Tesla.Env{status: 404, body: ""} end)

    conn = get(conn(), "/pub/remote_interaction?acct=nobody@unknown.local")

    assert redirected_to(conn) == "/remote_interaction"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
  end

  # what the form posts: the nick under `outgoing`, and its hidden `type` and `object` inputs at the top level
  defp form_params(me),
    do: %{"outgoing" => %{"me" => me}, "type" => "follow", "object" => @object}
end
