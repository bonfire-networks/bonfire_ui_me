defmodule Bonfire.UI.Me.Sudo do
  @moduledoc "Conn-side sudo proof: read and stamp the session's factors map, and check an action's requirement against it. The domain logic lives in `Bonfire.Me.SensitiveActions`."
  import Plug.Conn
  alias Bonfire.Me.SensitiveActions

  @doc "The session's factors map."
  def factors(conn), do: get_session(conn, :sudo_proof) || %{}

  @doc "Records an earned factor into the session (no-op for nil, e.g. SSO logins until {:sso, provider} ships)."
  def stamp(conn, nil), do: conn

  def stamp(conn, factor),
    do: put_session(conn, :sudo_proof, SensitiveActions.stamp(factors(conn), factor))

  @doc "Whether this session meets the action's factor requirement for this account."
  def met?(conn, module, account),
    do: SensitiveActions.fresh?(factors(conn), SensitiveActions.required(module, account))

  @doc "The strongest required factor this session hasn't freshly earned, or :met."
  def next_challenge(conn, module, account),
    do: SensitiveActions.next_challenge(factors(conn), SensitiveActions.required(module, account))

  @doc "Session lifecycle when a login lands: cross-account applies logout semantics (renew_session clears everything, keeping only the stashed go, so proof never migrates between accounts); same-account keeps just the session-ID rotation."
  def renew_session_for(conn, account_id) do
    previous = get_session(conn, :current_account_id)

    if is_nil(previous) or previous == account_id do
      configure_session(conn, renew: true)
    else
      go = get_session(conn, :go)

      conn
      |> Bonfire.UI.Common.Web.renew_session()
      |> then(&if(is_binary(go), do: put_session(&1, :go, go), else: &1))
    end
  end
end
