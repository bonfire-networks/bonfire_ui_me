if Application.compile_env(:bonfire_api_graphql, :modularity) != :disabled do
  defmodule Bonfire.API.MastoCompatible.AccountController do
    use Bonfire.UI.Common.Web, :controller

    alias Bonfire.Me.API.GraphQLMasto.Adapter

    def show(conn, %{"id" => "verify_credentials"} = params), do: Adapter.me(conn)

    def show(conn, %{"id" => id} = params),
      do: Adapter.user(%{"filter" => %{"id" => id}}, conn)

    def show(conn, params), do: Adapter.user(params, conn)

    def verify_credentials(conn, params), do: Adapter.me(params, conn)

    def show_preferences(conn, params), do: Adapter.get_preferences(params, conn)

    # Mutes and Blocks endpoints
    def mutes(conn, params), do: Adapter.mutes(params, conn)
    def blocks(conn, params), do: Adapter.blocks(params, conn)

    def mute(conn, %{"id" => id}), do: Adapter.mute_account(%{"id" => id}, conn)
    def unmute(conn, %{"id" => id}), do: Adapter.unmute_account(%{"id" => id}, conn)
    def block(conn, %{"id" => id}), do: Adapter.block_account(%{"id" => id}, conn)
    def unblock(conn, %{"id" => id}), do: Adapter.unblock_account(%{"id" => id}, conn)
  end
end
