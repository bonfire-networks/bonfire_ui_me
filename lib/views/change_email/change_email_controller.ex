defmodule Bonfire.UI.Me.ChangeEmailController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.SensitiveActions.ChangeEmail
  alias Bonfire.UI.Me.AccountVerificationController
  alias Bonfire.UI.Me.ChangeEmailLive
  alias Bonfire.UI.Me.Sudo

  def index(conn, _), do: live_render(conn, ChangeEmailLive)

  def create(conn, params) do
    current_account = current_account(conn)
    attrs = Map.get(params, "change_email_fields") || params

    # a valid request still has to come from a recently verified session: otherwise the person is sent to verify first, and the change applies from the confirm page afterwards
    case Accounts.validate_change_email(current_account, attrs) do
      {:ok, new_email} ->
        if Sudo.met?(conn, ChangeEmail, current_account) do
          change(conn, current_account, attrs)
        else
          action = inspect(ChangeEmail)

          redirect_to(
            conn,
            AccountVerificationController.verify_path(
              action,
              AccountVerificationController.confirm_url(action, new_email, nil)
            )
          )
        end

      error ->
        failed(conn, error)
    end
  end

  defp change(conn, current_account, attrs) do
    case Accounts.change_email(current_account, attrs) do
      {:ok, account} -> changed(conn, account)
      error -> failed(conn, error)
    end
  end

  defp failed(conn, {:error, :not_found}) do
    conn
    |> assign_flash(
      :error,
      l("Unable to change your email. Try entering your old email correctly...")
    )
    |> assign(:error, :not_found)
    |> live_render(ChangeEmailLive)
  end

  defp failed(conn, {:error, changeset}) do
    error(changeset)

    conn
    |> assign_flash(
      :error,
      l("Unable to change your email. Try entering a valid email address...")
    )
    |> assign(:error, :invalid)
    |> assign(:form, changeset)
    |> live_render(ChangeEmailLive)
  end

  def form_cs(params \\ %{}), do: Accounts.changeset(:change_email, params)

  defp changed(conn, account) do
    conn
    # the account's other sessions end, this one stays signed in
    |> Sudo.revoke_other_sessions(account)
    |> assign_flash(
      :info,
      l("Please check your email for a confirmation link...")
    )
    |> redirect_to(path(:home))
  end
end
