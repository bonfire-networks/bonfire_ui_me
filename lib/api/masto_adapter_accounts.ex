if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.API.MastoCompatible.AccountController do
    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.API.GraphQL.RestAdapter
    alias Bonfire.UI.Me.API.MastoCompatible

    def show(conn, %{"id" => "verify_credentials"} = params), do: MastoCompatible.me(conn)

    def show(conn, %{"id" => id} = params),
      do: MastoCompatible.user(%{"filter" => %{"id" => id}}, conn)

    def show(conn, params), do: MastoCompatible.user(params, conn)

    def verify_credentials(conn, params), do: MastoCompatible.me(params, conn)
  end
end
