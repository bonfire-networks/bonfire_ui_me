defmodule Bonfire.UI.Me.CreateUserController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.CreateUserLive

  # GET only supports 'go'
  def index(conn, _) do
    conn = fetch_query_params(conn)
    params = Map.take(conn.query_params, [:go, "go"])

    paint(
      conn,
      Users.changeset(:create, params, e(conn.assigns, :current_account, nil))
    )
  end

  def create(conn, params) do
    debug(params)

    form = Map.get(params, "user", %{})

    changeset = Users.changeset(:create, form, e(conn.assigns, :current_account, nil))

    case Users.create(changeset,
           undiscoverable: not empty?(Map.get(params, "undiscoverable")),
           request_before_follow: not is_nil(Map.get(params, "request_before_follow"))
         ) do
      {:ok, %{id: id, profile: %{name: name}} = _user} ->
        greet(conn, params, id, name)

      {:ok, %{id: id, character: %{username: username}} = _user} ->
        greet(conn, params, id, username)

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

  defp greet(conn, params, id, name) do
    conn
    |> put_session(:user_id, id)
    |> assign_flash(:info, l("Hey %{name}, nice to meet you!", name: name))
    |> redirect_to_previous_go(params, "/", "/create-user")
  end

  defp paint(conn, changeset) do
    conn
    |> assign(:form, changeset)
    |> live_render(CreateUserLive)
  end
end
