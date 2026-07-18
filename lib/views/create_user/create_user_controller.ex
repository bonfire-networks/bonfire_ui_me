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

  # Resolve the chosen creator persona to one of the account's OWN users (so you can't link someone else's profile). Nil when none chosen or the account has no users yet.
  defp resolve_creator_user(user_id, account) when is_binary(user_id) and user_id != "" do
    Users.by_account(account)
    |> Enum.find(&(id(&1) == user_id))
  end

  defp resolve_creator_user(_user_id, _account), do: nil

  defp acknowledgements_accepted?(params) do
    # the extra consent checkbox is only required when the instance has enabled it (see `[:terms, :extra_consent]`)
    extra_consent_ok? =
      not Bonfire.UI.Me.CreateUserViewLive.extra_consent_enabled?() or
        not empty?(Map.get(params, "extra_consent"))

    extra_consent_ok? and
      not empty?(Map.get(params, "code_of_conduct_consent"))
  end

  defp create_from_changeset(conn, params, changeset) do
    case Users.create(changeset,
           context: conn.assigns,
           open_id_provider: Plug.Conn.get_session(conn, :open_id_provider),
           undiscoverable: not empty?(Map.get(params, "undiscoverable")),
           unindexable: not empty?(Map.get(params, "unindexable")),
           request_before_follow: not is_nil(Map.get(params, "request_before_follow")),
           # nil for a personal profile; a (possibly empty, defaulted downstream) label string makes it an organisation shared user
           shared_user_label:
             if(Map.get(params, "type") == "organisation", do: Map.get(params, "label", "")),
           # for an organisation, the account persona chosen (or auto-picked) to be its first co-manager
           shared_user_creator:
             if(Map.get(params, "type") == "organisation",
               do:
                 resolve_creator_user(
                   Map.get(params, "creator_user_id"),
                   current_account(conn.assigns)
                 )
             )
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
    |> redirect_after_create(params)
  end

  # Step 2 for organisations: land on a dedicated invite view (which reuses the Team Profiles invite + roster component) so the creator can optionally add co-managers or click Done to skip.
  defp redirect_after_create(conn, %{"type" => "organisation"}),
    do: redirect(conn, to: "/create-user/team")

  defp redirect_after_create(conn, params),
    do: redirect_to_previous_go(conn, params, "/", "/create-user")

  defp paint(conn, changeset) do
    # Pass the profile kind through the LiveView session, not conn assigns: a controller-rendered LiveView re-mounts over the websocket where conn assigns are gone, so an assign-based value would be lost on the connected mount (the form would flip back to personal in the browser). The session survives both the disconnected and connected mounts. `conn.params` merges the GET query (?type=organisation) and the POST body (hidden `type`/`label`), so the initial render and a validation re-render both keep it.
    conn
    |> assign(:form, changeset)
    |> live_render(CreateUserLive,
      session: %{
        "profile_type" => conn.params["type"],
        "profile_label" => conn.params["label"]
      }
    )
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
