defmodule Bonfire.UI.Me.ConfirmEmailController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ConfirmEmailLive

  def index(conn, _), do: live_render(conn, ConfirmEmailLive)

  def show(conn, %{"id" => token}) do
    case Accounts.confirm_email(token) do
      {:ok, account} ->
        confirmed(conn, account)

      {:error, :already_confirmed, _} ->
        already_confirmed(conn)

      {:error, :expired, _} ->
        show_error(conn, :expired)

      {:error, :expired} ->
        show_error(conn, :expired)

      e ->
        error(e)
        show_error(conn, :not_found)
    end
  end

  def create(conn, params) do
    form = Map.get(params, "confirm_email_fields", %{})

    case Accounts.request_confirm_email(form_cs(form), confirm_action: :confirm_again) do
      {:ok, _, _} ->
        conn
        |> put_session(:requested, true)
        |> live_render(ConfirmEmailLive)

      {:error, :already_confirmed} ->
        already_confirmed(conn)

      {:error, :not_found} ->
        conn
        |> assign(:error, :not_found)
        |> live_render(ConfirmEmailLive)

      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> live_render(ConfirmEmailLive)
    end
  end

  defp form_cs(params), do: Accounts.changeset(:confirm_email, params)

  defp confirmed(conn, %{id: id}) do
    conn
    |> put_session(:current_account_id, id)
    |> assign_flash(
      :info,
      l(
        "Welcome back! Thanks for confirming your email address. You can now create a user profile."
      )
    )
    |> redirect_to(path(:switch_user) || "/switch-user/")
  end

  defp already_confirmed(conn) do
    conn
    |> assign_flash(
      :error,
      l("You've already confirmed your email address. You can log in now.")
    )
    |> redirect_to(path(:login))
  end

  defp show_error(conn, text) do
    error(text)

    conn
    |> put_session(:error, text)
    |> live_render(ConfirmEmailLive)
  end
end
