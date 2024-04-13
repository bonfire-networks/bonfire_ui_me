if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.UI.Me.API.GraphQL.RestAdapter do
    use Bonfire.UI.Common.Web, :controller

    use Absinthe.Phoenix.Controller,
      schema: Bonfire.API.GraphQL.Schema,
      action: [mode: :internal]

    alias Bonfire.API.GraphQL.RestAdapter

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
      profile {
        icon
        image
        location
        name
        summary
        website
      }
      character {
        username
      }
    }
    }"
    def user(conn, data), do: RestAdapter.return(:user, data, conn)
    # def user(conn, params \\ %{}), do: RestAdapter.execute(:users, params, __MODULE__, conn)
  end
end
