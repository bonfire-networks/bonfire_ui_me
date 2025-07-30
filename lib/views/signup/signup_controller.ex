defmodule Bonfire.UI.Me.SignupController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.SignupLive

  def index(conn, params) do
    secret =
      Plug.Conn.get_session(conn, :auth_second_factor_secret) ||
        Bonfire.Me.Accounts.SecondFactors.new()

    if invite = params["invite"] do
      # Store invite in session if provided in params
      Plug.Conn.put_session(conn, :invite, invite)
    else
      conn
    end
    |> Plug.Conn.put_session(:auth_second_factor_secret, secret)
    |> render_view(Map.put(params, "auth_second_factor_secret", secret))
  end

  def create(conn, form) do
    {account_attrs, form} = Map.pop(form, "account", %{})

    case attempt(conn, account_attrs, form) do
      {:ok, conn} ->
        conn

      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> render_view(form)

      {:error, changeset} ->
        conn
        |> assign(
          :error,
          EctoSparkles.Changesets.Errors.changeset_errors_string(
            changeset,
            false
          )
        )
        # FIXME?
        |> assign(:form, changeset)
        |> render_view(form)
    end
  end

  def attempt(conn, account_attrs, form \\ %{}, opts \\ []) do
    # debug(Plug.Conn.get_session(conn, :auth_second_factor_secret))
    # changeset = form_cs(conn, params)

    case attempt_signup(conn, account_attrs, form, opts) do
      {:ok, %{email: %{confirmed_at: confirmed_at}} = account} when not is_nil(confirmed_at) ->
        Bonfire.UI.Me.LoginController.logged_in(account, nil, conn)

      {:ok, _account} ->
        {:ok,
         conn
         |> assign(:registered, :check_email)
         |> render_view(Map.put(form, "registered", :check_email))}

      other ->
        error(other)
    end
  end

  def attempt_signup(conn, account_attrs, form \\ %{}, opts \\ []) do
    debug(account_attrs, "Account attributes")

    Accounts.signup(
      account_attrs,
      opts
      |> Keyword.merge(
        invite: form["invite"] || account_attrs["invite"] || Plug.Conn.get_session(conn, :invite),
        auth_second_factor_secret: Plug.Conn.get_session(conn, :auth_second_factor_secret),
        open_id_provider: Plug.Conn.get_session(conn, :open_id_provider)
      )
    )
    |> info("attempted signup")
  end

  def render_view(conn, session_params \\ %{}) do
    conn
    |> live_render(
      SignupLive,
      session: session_params
    )
  end

  def form_cs(session) do
    # debug(session)
    Accounts.changeset(
      :signup,
      %{},
      invite: e(session, "invite", nil)

      # auth_second_factor_secret: e(session, "auth_second_factor_secret", nil)
    )

    # |> debug()
  end
end
