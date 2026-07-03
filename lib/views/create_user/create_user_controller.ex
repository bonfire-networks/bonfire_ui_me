defmodule Bonfire.UI.Me.CreateUserController do
  use Bonfire.UI.Common.Web, :controller

  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.CreateUserLive
  alias Bonfire.Me.Accounts
  # GET only supports 'go'
  def index(conn, _) do
    conn = fetch_query_params(conn)
    params = Map.take(conn.query_params, [:go, "go"])

    case Users.changeset(:create, params, current_account(conn.assigns)) do
      {:error, _reason} ->
        conn
        |> assign_flash(:error, l("You need to log in first."))
        |> redirect(to: path(:login, :login))

      changeset ->
        paint(conn, changeset)
    end
  end

  def create(conn, params) do
    debug(params)

    form = Map.get(params, "user", %{})

    case Users.changeset(:create, form, current_account(conn.assigns)) do
      {:error, _reason} ->
        conn
        |> assign_flash(:error, l("You need to log in first."))
        |> redirect(to: path(:login, :login))

      changeset ->
        if acknowledgements_accepted?(params) or !changeset.valid? do
          create_from_changeset(conn, params, changeset)
        else
          conn
          |> assign_flash(
            :error,
            l("Please confirm the required acknowledgements before creating your profile.")
          )
          |> paint(changeset)
        end
    end
  end

  defp acknowledgements_accepted?(params) do
    not empty?(Map.get(params, "political_consent")) and
      not empty?(Map.get(params, "code_of_conduct_consent"))
  end

  defp create_from_changeset(conn, params, changeset) do
    case Users.create(changeset,
           context: conn.assigns,
           open_id_provider: Plug.Conn.get_session(conn, :open_id_provider),
           undiscoverable: not empty?(Map.get(params, "undiscoverable")),
           unindexable: not empty?(Map.get(params, "unindexable")),
           request_before_follow: not is_nil(Map.get(params, "request_before_follow"))
         ) do
      {:ok, %{id: id, profile: %{name: name}} = user} ->
        conn
        |> put_session(:open_id_provider, nil)
        |> greet(params, id, name, Accounts.is_admin?(user))

      {:ok, %{id: id, character: %{username: username}} = user} ->
        conn
        |> put_session(:open_id_provider, nil)
        |> greet(params, id, username, Accounts.is_admin?(user))

      {:error, changeset} ->
        debug(changeset_error: changeset)

        conn
        |> assign_flash(
          :error,
          l("Please double check your inputs: ") <> flat_changeset_errors(changeset)
        )
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

  # Walks traversed changeset errors and produces a comma-separated, user-facing
  # list like "Name can't be blank, Username has invalid format" — without
  # exposing nested-changeset parent keys (e.g. "Profile:", "Character:").
  defp flat_changeset_errors(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> collect_errors()
    |> Enum.join(", ")
  end

  defp collect_errors(errors) when is_map(errors) do
    Enum.flat_map(errors, fn
      {field, msgs} when is_list(msgs) ->
        Enum.map(msgs, &"#{humanize_field(field)} #{&1}")

      {_field, nested} when is_map(nested) ->
        collect_errors(nested)
    end)
  end

  defp humanize_field(field) do
    field
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
