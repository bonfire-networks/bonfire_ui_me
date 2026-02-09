defmodule Bonfire.UI.Me.ConfirmEmailController do
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.ConfirmEmailLive

  def index(conn, _), do: live_render(conn, ConfirmEmailLive)

  def show(conn, %{"id" => token} = params) do
    redirect_uri = params["redirect_uri"]

    case Accounts.confirm_email(token) do
      {:ok, account} ->
        confirmed(conn, account, redirect_uri)

      {:error, :already_confirmed, _} ->
        already_confirmed(conn, redirect_uri)

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
        already_confirmed(conn, nil)

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

  defp confirmed(conn, %{id: id}, redirect_uri) do
    conn = put_session(conn, :current_account_id, id)

    conn
    |> assign_flash(
      :info,
      l("Thanks for confirming your email address. Please create a user profile.")
    )
    |> redirect_to(validate_redirect_uri(redirect_uri, path(:switch_user) || "/switch-user/"),
      type: :maybe_external
    )
  end

  defp already_confirmed(conn, redirect_uri) do
    conn
    |> assign_flash(
      :error,
      l("You've already confirmed your email address. You can log in now.")
    )
    |> redirect_to(validate_redirect_uri(redirect_uri, path(:login) || "/login/"),
      type: :maybe_external
    )
  end

  defp show_error(conn, text) do
    error(text)

    conn
    |> put_session(:error, text)
    |> live_render(ConfirmEmailLive)
  end

  # Validate redirect_uri is safe for mobile app deep-linking
  # Only allows custom URL schemes (e.g., myapp://, com.example.app://)
  # Blocks web URLs and other schemes
  @blocked_schemes ~w(http https javascript data file mailto tel sms ftp)

  defp validate_redirect_uri(nil, default), do: default
  defp validate_redirect_uri("", default), do: default

  defp validate_redirect_uri(uri, default) when is_binary(uri) do
    case URI.parse(uri) do
      # Only allow custom schemes - these open the registered mobile app
      %URI{scheme: scheme} when is_binary(scheme) and scheme != "" ->
        if scheme in @blocked_schemes do
          default
        else
          uri
        end

      _ ->
        default
    end
  end

  defp validate_redirect_uri(_, default), do: default
end
