defmodule Bonfire.UI.Me.EmbedAllowedOriginTest do
  @moduledoc """
  Regression tests for the allowlist that decides whether we mint a cross-origin embed
  token for a `go` URL after login (`IFRAME_ALLOWED_ORIGINS`).

  The token is a long-lived bearer credential handed to the target page, so "is this an
  allowed origin?" must compare a full **origin** (scheme + host + port) — not just the
  host. A host-only match authorises `http://` (MITM-able) and any port on that host.
  """
  # `async: false` — mutates a system env var.
  use ExUnit.Case, async: false

  alias Bonfire.UI.Me.LoginController

  defp with_allowed(value, fun) do
    previous = System.get_env("IFRAME_ALLOWED_ORIGINS")
    System.put_env("IFRAME_ALLOWED_ORIGINS", value)

    try do
      fun.()
    after
      if previous,
        do: System.put_env("IFRAME_ALLOWED_ORIGINS", previous),
        else: System.delete_env("IFRAME_ALLOWED_ORIGINS")
    end
  end

  describe "embed_allowed_origin?/1 (M2)" do
    test "the exact allowed origin matches" do
      with_allowed("https://blog.example.com", fn ->
        assert LoginController.embed_allowed_origin?("https://blog.example.com/some/post")
      end)
    end

    test "a different host does not match" do
      with_allowed("https://blog.example.com", fn ->
        refute LoginController.embed_allowed_origin?("https://evil.example.com/")
      end)
    end

    test "a plaintext http:// origin on an allowed host is NOT allowed" do
      with_allowed("https://blog.example.com", fn ->
        refute LoginController.embed_allowed_origin?("http://blog.example.com/some/post"),
               "minted an embed token for a plaintext origin — token is MITM-able in transit"
      end)
    end

    test "a different port on an allowed host is NOT allowed" do
      with_allowed("https://blog.example.com", fn ->
        refute LoginController.embed_allowed_origin?("https://blog.example.com:8443/"),
               "minted an embed token for a different port — a service on another port could harvest it"
      end)
    end

    test "a wildcard does not authorise token minting" do
      # `*` is meaningful to CSP `frame-ancestors` (IframeEmbeddablePlug), but must never
      # mean "mint a bearer token for anyone".
      with_allowed("*", fn ->
        refute LoginController.embed_allowed_origin?("https://evil.example.com/")
      end)
    end

    test "an empty allowlist authorises nothing" do
      with_allowed("", fn ->
        refute LoginController.embed_allowed_origin?("https://blog.example.com/")
      end)
    end

    test "localhost over http is still allowed (local embed development)" do
      with_allowed("http://localhost:2368", fn ->
        assert LoginController.embed_allowed_origin?("http://localhost:2368/my-article/")
      end)
    end

    test "explicit ports must match exactly" do
      with_allowed("http://localhost:2368", fn ->
        refute LoginController.embed_allowed_origin?("http://localhost:3000/")
      end)
    end

    test "a default port is equivalent to an explicit one" do
      with_allowed("https://blog.example.com:443", fn ->
        assert LoginController.embed_allowed_origin?("https://blog.example.com/post")
      end)
    end

    test "a bare host:port entry matches its own origin" do
      # URI.parse("blog.example.com:8443") reads the host as a SCHEME, so this form used to
      # match nothing at all — login succeeded but no embed token was ever minted.
      with_allowed("blog.example.com:8443", fn ->
        assert LoginController.embed_allowed_origin?("https://blog.example.com:8443/post")
        refute LoginController.embed_allowed_origin?("https://blog.example.com/post")
      end)
    end

    test "host and scheme comparison is case-insensitive (RFC 3986)" do
      with_allowed("https://blog.example.com", fn ->
        assert LoginController.embed_allowed_origin?("https://BLOG.example.com/post")
      end)

      with_allowed("https://BLOG.Example.com", fn ->
        assert LoginController.embed_allowed_origin?("https://blog.example.com/post")
      end)
    end

    test "several space-separated origins are each honoured" do
      with_allowed("https://a.example.com https://b.example.com", fn ->
        assert LoginController.embed_allowed_origin?("https://a.example.com/x")
        assert LoginController.embed_allowed_origin?("https://b.example.com/y")
        refute LoginController.embed_allowed_origin?("https://c.example.com/z")
      end)
    end
  end
end
