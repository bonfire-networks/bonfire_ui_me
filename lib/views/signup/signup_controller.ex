defmodule Bonfire.UI.Me.SignupController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.SignupLive

  def index(conn, params) do
    conn
    |> maybe_assign_secret(params)
    |> render_view(params)
  end

  def create(conn, params) do
    {account_attrs, params} = Map.pop(params, "account", %{})
    # debug(Plug.Conn.get_session(conn, :auth_two_factor_secret))
    # changeset = form_cs(conn, params)
    ret = Accounts.signup(account_attrs, invite: params["invite"], auth_two_factor_secret: Plug.Conn.get_session(conn, :auth_two_factor_secret)) |> debug()
    case ret do
      {:ok, %{email: %{confirmed_at: confirmed_at}}} when not is_nil(confirmed_at) ->
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
        |> assign(:error, EctoSparkles.Changesets.Errors.changeset_errors_string(changeset, false))
        |> assign(:form, changeset) # FIXME
        |> render_view(params, changeset)
    end
  end

  def render_view(conn, params, changeset \\ nil) do
    conn
    |> live_render(SignupLive, session: params)
  end

  def form_cs(session) do
    # debug(session)
    Accounts.changeset(:signup,
      %{},
      invite: e(session, "invite", nil),
      auth_two_factor_secret: e(session, "auth_two_factor_secret", nil)
    )
    # |> debug()
  end

  def maybe_assign_secret(conn, opts \\ []) do
    if Bonfire.Me.Accounts.SecondFactors.enabled? do
      conn
      |> Plug.Conn.put_session(:auth_two_factor_secret, Bonfire.Me.Accounts.SecondFactors.new())
      # |> debug
    else
      conn
    end
  end

end
