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

  def create(conn, params) do
    {account_attrs, params} = Map.pop(params, "account", %{})
    # debug(Plug.Conn.get_session(conn, :auth_second_factor_secret))
    # changeset = form_cs(conn, params)
    case Accounts.signup(account_attrs,
           invite: params["invite"],
           auth_second_factor_secret: Plug.Conn.get_session(conn, :auth_second_factor_secret)
         ) do
      {:ok, %{email: %{confirmed_at: confirmed_at}}}
      when not is_nil(confirmed_at) ->
        conn
        |> assign(:registered, :confirmed)
        |> render_view(Map.put(params, "registered", :confirmed))

      {:ok, _account} ->
        conn
        |> assign(:registered, :check_email)
        |> render_view(Map.put(params, "registered", :check_email))

      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> render_view(params)

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
        |> render_view(params, changeset)
    end
  end

  def render_view(conn, params, changeset \\ nil) do
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
