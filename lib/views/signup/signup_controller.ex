defmodule Bonfire.UI.Me.SignupController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.SignupLive

  def index(conn, params) do
    secret =
      Plug.Conn.get_session(conn, :auth_second_factor_secret) ||
        Bonfire.Me.Accounts.SecondFactors.new()

    conn
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
        # FIXME
        |> assign(:form, changeset)
        |> render_view(form, changeset)
    end
  end

  def attempt(conn, account_attrs, form \\ %{}) do
    # debug(Plug.Conn.get_session(conn, :auth_second_factor_secret))
    # changeset = form_cs(conn, params)
    info(account_attrs, "Account attributes")

    case Accounts.signup(account_attrs,
           # TODO: || Plug.Conn.get_session(conn, :invite)
           invite: form["invite"] || account_attrs["invite"],
           auth_second_factor_secret: Plug.Conn.get_session(conn, :auth_second_factor_secret)
         )
         |> info("attempted signup") do
      {:ok, %{email: %{confirmed_at: confirmed_at}}} when not is_nil(confirmed_at) ->
        {:ok,
         conn
         |> assign(:registered, :confirmed)
         |> render_view(Map.put(form, "registered", :confirmed))}

      {:ok, _account} ->
        {:ok,
         conn
         |> assign(:registered, :check_email)
         |> render_view(Map.put(form, "registered", :check_email))}

      other ->
        error(other)
    end
  end

  def render_view(conn, params, _changeset \\ nil) do
    live_render(
      conn,
      SignupLive,
      session: params
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
