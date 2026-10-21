defmodule Bonfire.UI.Me.LoginLinkController do
  @moduledoc "The page behind a magic-link sign-in email. Opening the link only shows a page, and its button signs the person in, so a mail scanner opening the link can't use the token up. Password reset links have their own page in `Bonfire.UI.Me.ForgotPasswordController`. See `Bonfire.UI.Me.EmailLink`."
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.Accounts
  alias Bonfire.Me.Users
  alias Bonfire.UI.Me.EmailLink
  alias Bonfire.UI.Me.ForgotPasswordController
  alias Bonfire.UI.Me.LoginController

  def show(conn, %{"login_token" => token}) do
    case Accounts.check_confirm_token(token, confirm_action: :login) do
      :ok ->
        EmailLink.confirm_page(conn, "/login/email/" <> URI.encode_www_form(token),
          title: l("Sign in"),
          intro: l("Press the button to finish signing in."),
          button: l("Sign in")
        )

      _ ->
        ForgotPasswordController.invalid_link(conn)
    end
  end

  def redeem(conn, %{"login_token" => token}) do
    conn = EmailLink.stash_go(conn)
    # the initiating profile, restored after redemption when this account owns it
    as_user = conn.query_params["as_user"]

    case Accounts.confirm_email(token, confirm_action: :login) do
      {:ok, account} -> magic_link_login(conn, account, as_user)
      {:error, _} -> ForgotPasswordController.invalid_link(conn)
    end
  end

  defp magic_link_login(conn, account, as_user) do
    # prefer the link's initiating profile (validated as accessible to this account), else the account's only profile
    user =
      Users.get_in_account(as_user, account.id) ||
        case Users.get_only_in_account(account) do
          {:ok, user} -> user
          _ -> nil
        end

    # `go` was stashed in the session in `redeem/2`, so `logged_in/5` (and the
    # switch-user / create-profile tails) all recover it via `redirect_to_previous_go`
    # — no need to thread it through the form here.
    LoginController.logged_in(account, user, conn, %{}, :email)
  end
end
