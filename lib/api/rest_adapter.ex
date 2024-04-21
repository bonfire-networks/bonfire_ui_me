if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.UI.Me.API.GraphQL.RestAdapter do
    use Bonfire.UI.Common.Web, :controller

    use Absinthe.Phoenix.Controller,
      schema: Bonfire.API.GraphQL.Schema,
      action: [mode: :internal]

    alias Bonfire.API.GraphQL.RestAdapter

    @user_profile "
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
    }"

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
        #{@user_profile}
    }}"
    def user(conn, data), do: RestAdapter.return(:user, data, conn)

    @graphql "query {
        me { 
         user { #{@user_profile} }
      }}"
    def me(conn, data), do: RestAdapter.return(:user, data, conn)
  end
end
