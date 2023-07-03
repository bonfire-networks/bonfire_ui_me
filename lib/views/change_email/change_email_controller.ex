defmodule Bonfire.UI.Me.ChangeEmailController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ChangeEmailLive

  def index(conn, _), do: live_render(conn, ChangeEmailLive)

  def create(conn, params) do
    current_account = current_account(conn)
    attrs = Map.get(params, "change_email_fields") || params

    case Accounts.change_email(current_account, attrs) do
      {:ok, account} ->
        changed(conn, account)

      {:error, :not_found} ->
        conn
        |> assign_flash(
          :error,
          l("Unable to change your email. Try entering your old email correctly...")
        )
        |> assign(:error, :not_found)
        |> live_render(ChangeEmailLive)

      {:error, changeset} ->
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
  end

  def form_cs(params \\ %{}), do: Accounts.changeset(:change_email, params)

  defp changed(conn, _account) do
    conn
    |> assign_flash(
      :info,
      l("Please check your email for a confirmation link...")
    )
    |> redirect(to: path(:home))
  end
end
