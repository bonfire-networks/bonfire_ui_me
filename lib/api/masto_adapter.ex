if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.UI.Me.API.MastoCompatible do
    # use Bonfire.UI.Common.Web, :controller
    use Arrows
    import Untangle

    use AbsintheClient,
      schema: Bonfire.API.GraphQL.Schema,
      action: [mode: :internal]

    alias Bonfire.API.GraphQL.RestAdapter

    @user_profile "
      id
    created_at: date_created
    profile {
      avatar: icon
      header: image
      location
      display_name: name
      note: summary
      website
    }
    character {
      username
      acct: username
      url: canonical_uri
    }"

    @graphql "query ($filter: CharacterFilters) {
      user(filter: $filter) {
        #{@user_profile}
    }}"
    def user(params, conn) do
      user = graphql(conn, :user, debug(params))

      RestAdapter.return(:user, user, conn, fn user ->
        user
        |> Map.drop([:profile, :character])
        |> Map.merge(Map.merge(user[:profile] || %{}, user[:character] || %{}))
      end)
    end

    @graphql "query {
        me { 
         user { #{@user_profile} }
      }}"
    def me(params \\ %{}, conn),
      do: graphql(conn, :me, params) |> RestAdapter.return(:user, ..., conn)
  end
end
