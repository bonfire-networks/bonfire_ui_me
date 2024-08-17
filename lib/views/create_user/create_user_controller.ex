defmodule Bonfire.UI.Me.CreateUserController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.CreateUserLive
  alias Bonfire.Me.Accounts
  # GET only supports 'go'
  def index(conn, _) do
    conn = fetch_query_params(conn)
    params = Map.take(conn.query_params, [:go, "go"])

    paint(
      conn,
      Users.changeset(:create, params, current_account(conn.assigns))
    )
  end

  def create(conn, params) do
    debug(params)

    form = Map.get(params, "user", %{})

    changeset = Users.changeset(:create, form, current_account(conn.assigns))

    case Users.create(changeset,
           undiscoverable: not empty?(Map.get(params, "undiscoverable")),
           unindexable: not empty?(Map.get(params, "unindexable")),
           request_before_follow: not is_nil(Map.get(params, "request_before_follow"))
         ) do
      {:ok, %{id: id, profile: %{name: name}} = user} ->
        greet(conn, params, id, name, Accounts.is_admin?(user))

      {:ok, %{id: id, character: %{username: username}} = user} ->
        greet(conn, params, id, username, Accounts.is_admin?(user))

      {:error, changeset} ->
        debug(changeset_error: changeset)
        # |> IO.inspect
        err =
          EctoSparkles.Changesets.Errors.changeset_errors_string(
            changeset,
            false
          )

        conn
        |> assign(:error, err)
        |> assign_flash(:error, l("Please double check your inputs... ") <> err)
        |> paint(changeset)

      r ->
        debug(create_user: r)

        conn
        |> assign_flash(:error, l("An unexpected error occured... "))
        |> paint(changeset)
    end
  end

  defp build_greet_message(name, true) do
    build_greet_message(name, nil) <> " " <> l("You have been promoted to admin!")
  end

  defp build_greet_message(name, _) do
    l("Hey %{name}, nice to meet you!", name: name)
  end

  defp greet(conn, params, id, name, is_admin) do
    conn
    |> Bonfire.Me.Users.LiveHandler.disconnect_user_session()
    |> put_session(:current_user_id, id)
    |> assign_flash(:info, build_greet_message(name, is_admin))
    |> redirect_to_previous_go(params, "/", "/create-user")
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(CreateUserLive)
  end
end
