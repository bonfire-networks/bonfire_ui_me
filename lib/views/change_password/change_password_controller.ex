defmodule Bonfire.UI.Me.ChangePasswordController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ChangePasswordLive

  def index(conn, params) do
    # stash a return-to path (e.g. a destructive-action modal that sent the user here to set/reset a
    # password) so `changed/2` can send them back after saving; reuses the shared `:go` session flow
    conn
    |> maybe_set_go_after(params)
    |> live_render(ChangePasswordLive)
  end

  def create(conn, params) do
    current_account = current_account(conn)
    attrs = Map.get(params, "change_password_fields", params)

    case Accounts.change_password(current_account, attrs,
           resetting_password: skip_old_password?(get_session(conn), current_account)
         ) do
      {:ok, account} ->
        changed(conn, account)

      {:error, :not_found} ->
        conn
        |> assign_flash(
          :error,
          l("Unable to change your password. Try entering your old password correctly...")
        )
        |> assign(:error, :not_found)
        |> live_render(ChangePasswordLive)

      {:error, changeset} ->
        conn
        |> assign_flash(
          :error,
          l("Unable to change your password. Try entering a longer password...")
        )
        |> assign(:error, :invalid)
        |> assign(:form, changeset)
        |> live_render(ChangePasswordLive)
    end
  end

  def form_cs(params \\ %{}), do: Accounts.changeset(:change_password, params)

  @doc """
  Whether this session may set a new password without typing the current one. `session` is the string-keyed session map (from a conn or a LiveView mount). True when:
  - a reset link was just redeemed (`resetting_password`), or
  - the account has no password yet (passwordless / magic-link accounts), or
  - the person just signed in by email link, which proves inbox control the same way a reset link does. This covers accounts holding a password nobody knows (e.g. provisioned with a random one) on passwordless instances, where "forgot password" sends a sign-in link rather than a reset.
  """
  def skip_old_password?(session, account) do
    !!session["resetting_password"] or !Accounts.account_has_password?(account) or
      Bonfire.Me.SensitiveActions.fresh?(session["sudo_proof"] || %{}, [:email])
  end

  defp changed(conn, _account) do
    conn
    |> delete_session(:resetting_password)
    # the user just set this password, so it counts as a live password factor (also how a reset self-recovers a sudo password challenge)
    |> Bonfire.UI.Me.Sudo.stamp(:password)
    |> assign_flash(
      :info,
      l("You have now changed your password. We recommend saving it in a password manager app!")
    )
    # return to where the user came from (e.g. the delete/migrate modal) if a `go` was stashed, else home
    |> redirect_to_previous_go(%{}, path(:home), conn.request_path)
  end
end
