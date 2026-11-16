defmodule Bonfire.UI.Me.OpenRedirectGoTest do
  @moduledoc """
  The `go` target after logout or login only ever leads to a local path or to this instance's own exact origin; look-alike hosts (the instance host as a prefix of another host, or as userinfo of another host) never get a redirect. The OAuth/OpenID authorize round trip depends on local and own-origin targets still working.
  """
  use Bonfire.UI.Me.ConnCase, async: false

  defp base, do: Bonfire.Common.URIs.base_url() |> String.trim_trailing("/")

  defp lookalikes do
    %{
      "prefix host" => base() <> ".evil.local/",
      "userinfo host" => base() <> "@evil.local/"
    }
  end

  defp location(conn) do
    assert conn.status in 300..399
    conn |> get_resp_header("location") |> List.first()
  end

  # a local path, or this instance's exact origin followed by a path/query/fragment boundary
  defp ours?(nil), do: false
  defp ours?("/" <> _), do: true

  defp ours?(loc),
    do: loc == base() or String.starts_with?(loc, [base() <> "/", base() <> "?", base() <> "#"])

  defp login_params(account) do
    %{
      "login_fields" => %{
        "email_or_username" => account.email.email_address,
        "password" => account.credential.password
      }
    }
  end

  # with a profile, so a successful login lands on `go` instead of the profile picker
  defp account! do
    account = fake_account!() |> Bonfire.Common.Repo.preload([:email, :credential])
    _user = fake_user!(account)
    account
  end

  describe "/logout?go=" do
    test "controls: a local path and our own exact origin are followed" do
      account = account!()

      assert location(get(conn(account: account), "/logout?go=/some/local/path")) ==
               "/some/local/path"

      assert location(
               get(
                 conn(account: account),
                 "/logout?go=" <> URI.encode_www_form(base() <> "/about")
               )
             ) == base() <> "/about"
    end

    for {name, _} <- [{"prefix host", nil}, {"userinfo host", nil}] do
      @name name
      test "does not redirect to a look-alike #{name}" do
        go = lookalikes()[@name]
        conn = get(conn(account: account!()), "/logout?go=" <> URI.encode_www_form(go))

        loc = location(conn)
        assert ours?(loc), "redirected to #{inspect(loc)} for go=#{go}"
      end
    end
  end

  describe "login with a saved go" do
    test "controls: a local path and our own exact origin survive login" do
      account = account!()

      for go <- ["/some/local/path", base() <> "/about"] do
        conn = post(conn(go: go), "/login", login_params(account))
        assert location(conn) == go
      end
    end

    test "controls: the same targets survive login when sent as the form's go field" do
      account = account!()

      for go <- ["/some/local/path", base() <> "/about"] do
        conn = post(conn(), "/login", Map.put(login_params(account), "go", go))
        assert location(conn) == go
      end
    end

    test "control: a local go in the login URL's query is followed" do
      conn =
        post(
          conn(),
          "/login?go=" <> URI.encode_www_form("/some/local/path"),
          login_params(account!())
        )

      assert location(conn) == "/some/local/path"
    end

    # the SSO round trip: /oauth/authorize (needs login) -> login -> back in /oauth/authorize, which then shows the consent screen
    test "control: login with an /oauth/authorize go resumes the authorization" do
      previous = Application.get_env(:bonfire_open_id, :oauth_module)
      Application.put_env(:bonfire_open_id, :oauth_module, Boruta.Oauth)
      on_exit(fn -> Application.put_env(:bonfire_open_id, :oauth_module, previous) end)

      account = account!()
      callback = "http://localhost:4000/oauth/client/open-redirect-go"

      client =
        Bonfire.OpenID.Provider.ClientApps.init_test_client_app(Faker.UUID.v4(), %{
          name: "Open redirect go control",
          redirect_uris: [callback],
          pkce: false,
          supported_scopes: ["read", "write"]
        })

      go =
        "/oauth/authorize?" <>
          URI.encode_query(%{
            "client_id" => client.id,
            "redirect_uri" => callback,
            "response_type" => "code",
            "state" => "xyz",
            "scope" => "read write"
          })

      conn = post(conn(go: go), "/login", login_params(account))

      assert conn.status == 200
      assert html_response(conn, 200) =~ "oauth_consent"
    end

    for {name, _} <- [{"prefix host", nil}, {"userinfo host", nil}] do
      @name name
      test "after login does not redirect to a look-alike #{name} (saved go cookie)" do
        account = account!()
        go = lookalikes()[@name]

        conn = post(conn(go: go), "/login", login_params(account))

        loc = location(conn)
        assert ours?(loc), "redirected to #{inspect(loc)} for go=#{go}"
      end

      test "after login does not redirect to a look-alike #{name} (go in the login URL's query)" do
        account = account!()
        go = lookalikes()[@name]

        conn =
          post(conn(), "/login?go=" <> URI.encode_www_form(go), login_params(account))

        loc = location(conn)
        assert ours?(loc), "redirected to #{inspect(loc)} for go=#{go}"
      end

      test "after login does not redirect to a look-alike #{name} (form go field)" do
        account = account!()
        go = lookalikes()[@name]

        conn = post(conn(), "/login", Map.put(login_params(account), "go", go))

        loc = location(conn)
        assert ours?(loc), "redirected to #{inspect(loc)} for go=#{go}"
      end
    end
  end
end
