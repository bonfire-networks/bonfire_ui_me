defmodule Bonfire.UI.Me.AccountVerificationController do
  @moduledoc "The sudo gate over HTTP: /account/verify challenges for the strongest required factor and stamps the session; /account/confirm renders an action's description and executes it behind fresh proof."
  use Bonfire.UI.Common.Web, :controller

  alias Bonfire.Me.Accounts
  alias Bonfire.Me.SensitiveActions
  alias Bonfire.UI.Me.AccountVerificationViewLive
  alias Bonfire.UI.Me.Sudo

  plug :protect_verification_response

  @doc "Renders the current challenge for the requested action, or redirects through go when the requirement is already met."
  def verify(conn, %{"for" => action} = params) do
    go = local_go(params["go"])

    with {:ok, account} <- logged_in_account(conn),
         {:ok, module} <- SensitiveActions.resolve(action) do
      required = SensitiveActions.required(module, account)
      description = describe(module, account, params)

      case SensitiveActions.next_challenge(Sudo.factors(conn), required) do
        :met ->
          redirect_to(conn, go)

        :password ->
          render_page(conn, :password, description, action: action, go: go)

        :email ->
          {conn, sent} = maybe_auto_send(conn, account, go, e(description, :title, nil))
          render_page(conn, :email, description, action: action, go: go, sent: sent)

        # a factor with no challenge UI yet (which should kept out of factor_strength until one exists)
        _ ->
          failure(conn)
      end
    else
      {:error, :needs_login} -> require_login(conn)
      _ -> failure(conn)
    end
  end

  def verify(conn, _), do: failure(conn)

  @doc "Checks the submitted password, stamps the :password factor and follows go."
  def password(conn, %{"for" => action} = params) do
    go = local_go(params["go"])

    with {:ok, account} <- logged_in_account(conn),
         {:ok, module} <- SensitiveActions.resolve(action) do
      cond do
        limit(conn, :sudo_password, account.id) != :ok ->
          failure(conn, :rate_limited)

        Accounts.login_valid?(account.id, params["password"] || "") ->
          conn
          |> Sudo.stamp(:password)
          |> redirect_to(go)

        true ->
          render_page(conn, :password, describe(module, account, params),
            action: action,
            go: go,
            error: l("That password didn't match. Please try again.")
          )
      end
    else
      {:error, :needs_login} -> require_login(conn)
      _ -> failure(conn)
    end
  end

  def password(conn, _), do: failure(conn)

  @doc "Sends (or re-mails) the login link for the :email challenge, or the reset escape from the password challenge."
  def send_email(conn, %{"for" => action} = params) do
    go = local_go(params["go"])

    with {:ok, account} <- logged_in_account(conn),
         {:ok, module} <- SensitiveActions.resolve(action),
         description = describe(module, account, params),
         :ok <- limit(conn, :sudo_email, account.id),
         {:ok, _, _} <-
           send_login_email(account, go, e(description, :title, nil), current_user_id(conn)) do
      render_page(conn, :email, description, action: action, go: go, sent: true)
    else
      {:error, :needs_login} -> require_login(conn)
      {:error, :rate_limited} -> failure(conn, :rate_limited)
      _ -> failure(conn)
    end
  end

  def send_email(conn, _), do: failure(conn)

  @doc "Renders the action's description and confirm button behind the sudo gate."
  def confirm(conn, %{"action" => action} = params) do
    with {:ok, account} <- logged_in_account(conn),
         {:ok, module} <- SensitiveActions.resolve(action) do
      if Sudo.met?(conn, module, account) do
        render_page(conn, :confirm, describe(module, account, params),
          action: action,
          target: params["target"],
          go: local_go(params["go"])
        )
      else
        redirect_to(conn, verify_path(action, confirm_url(action, params["target"])))
      end
    else
      {:error, :needs_login} -> require_login(conn)
      _ -> failure(conn)
    end
  end

  def confirm(conn, _), do: failure(conn)

  @doc "Executes the action behind CSRF and a POST-time freshness recheck."
  def execute(conn, %{"action" => action} = params) do
    with {:ok, account} <- logged_in_account(conn),
         {:ok, module} <- SensitiveActions.resolve(action),
         true <- Sudo.met?(conn, module, account),
         {:ok, _} <- module.execute(%{account: account, target_id: params["target"]}) do
      render_page(conn, :done, e(describe(module, account, params), :success, nil))
    else
      {:error, :needs_login} -> require_login(conn)
      false -> redirect_to(conn, verify_path(action, confirm_url(action, params["target"])))
      _ -> failure(conn)
    end
  end

  def execute(conn, _), do: failure(conn)

  defp logged_in_account(conn) do
    case current_account(conn) do
      nil -> {:error, :needs_login}
      account -> {:ok, account}
    end
  end

  defp describe(module, account, params),
    do: module.describe(%{account: account, target_id: params["target"]})

  defp verify_path(action, go),
    do: path(:sudo_verify) <> "?" <> URI.encode_query([{"for", action}, {"go", go}])

  defp confirm_url(action, target) do
    path(:sudo_confirm) <>
      "?" <>
      URI.encode_query(if target, do: [action: action, target: target], else: [action: action])
  end

  # go must be a local path; anything else falls back to home
  defp local_go("/" <> _ = go), do: if(String.starts_with?(go, "//"), do: "/", else: go)
  defp local_go(_), do: "/"

  defp require_login(conn) do
    conn
    |> clear_session()
    # opt in to keeping the query string, since the action rides in it
    |> set_go_after(current_path_with_query(conn))
    |> assign_flash(:error, l("You need to log in first."))
    |> redirect_to(path(:login))
  end

  defp current_path_with_query(%{query_string: ""} = conn), do: conn.request_path
  defp current_path_with_query(conn), do: conn.request_path <> "?" <> conn.query_string

  # skip the auto-send while an unexpired token is outstanding, so reloads never invalidate a link in flight
  defp maybe_auto_send(conn, account, go, intent) do
    account = repo().preload(account, :email)
    until = e(account, :email, :confirm_until, nil)

    if is_struct(until, DateTime) and Bonfire.Common.DatesTimes.future?(until) do
      {conn, false}
    else
      case send_login_email(account, go, intent, current_user_id(conn)) do
        {:ok, _, _} -> {conn, true}
        _ -> {conn, false}
      end
    end
  end

  defp send_login_email(account, go, intent, as_user) do
    account = repo().preload(account, :email)
    address = e(account, :email, :email_address, nil)

    # :forgot_password on password instances: anything else falls through to the signup-confirmation mail, whose URL is guest-only
    confirm_action = if Accounts.passwordless_only?(), do: :login, else: :forgot_password

    Accounts.request_confirm_email(%{email: address},
      confirm_action: confirm_action,
      go: go,
      # names the action in the mail body (the subject stays generic)
      sudo_intent: intent,
      # the initiating profile, so redemption on any device restores it (ownership-validated there)
      as_user: as_user,
      must_confirm?: true
    )
  end

  defp limit(conn, prefix, account_id) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    with :ok <-
           Bonfire.UI.Common.RateLimit.check(
             prefix,
             "account:#{account_id}",
             to_timeout(minute: 1),
             5
           ),
         :ok <- Bonfire.UI.Common.RateLimit.check(prefix, "ip:#{ip}", to_timeout(minute: 1), 25) do
      :ok
    else
      _ -> {:error, :rate_limited}
    end
  end

  defp failure(conn, reason \\ :not_available) do
    description =
      case reason do
        :rate_limited ->
          %{
            title: l("Too many attempts"),
            description: l("Please wait a minute before trying again.")
          }

        _ ->
          %{
            title: l("This action is not available"),
            description: l("The link may be incorrect, or this action may not be enabled here.")
          }
      end

    render_page(conn, :error, description)
  end

  defp render_page(conn, state, description, opts \\ []) do
    conn
    |> assign(:force_static, true)
    |> live_render(AccountVerificationViewLive,
      session: %{
        "state" => state,
        "description" => description,
        "action" => opts[:action],
        "target" => opts[:target],
        "go" => opts[:go],
        "error" => opts[:error],
        "sent" => opts[:sent]
      }
    )
  end

  defp protect_verification_response(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end
end
