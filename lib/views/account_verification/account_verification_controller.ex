defmodule Bonfire.UI.Me.AccountVerificationController do
  @moduledoc "HTTP verification and explicit confirmation, including browsers without a signed-in account."
  use Bonfire.UI.Common.Web, :controller
  alias Bonfire.Me.SensitiveActions, as: Actions
  alias Bonfire.UI.Me.AccountVerificationViewLive

  plug :protect_verification_response

  @doc "Shows an entry point without creating an intent on GET."
  def new(conn, %{"action" => action}) do
    with account when not is_nil(account) <- current_account(conn),
         {:ok, module} <- Actions.resolve(action) do
      render_page(conn, :start, module.describe(%{account: account, pending: nil}), action: action)
    else
      nil -> failure(conn, :needs_reauth)
      {:error, reason} -> failure(conn, reason)
    end
  end

  @doc "Creates an intent using the authenticated account, never an account supplied in the form."
  def start(conn, %{"action" => action}) do
    with account when not is_nil(account) <- current_account(conn),
         :ok <- limit(conn, :verification_start, account.id, 60_000, 5),
         {:ok, pending} <- Actions.create(account, action) do
      redirect(conn, to: page_path(pending.id))
    else
      nil -> failure(conn, :needs_reauth)
      {:error, reason} -> failure(conn, reason)
    end
  end

  @doc "Stores an unconsumed email link in this browser and removes it from the address bar."
  def email_link(conn, %{"id" => id, "token" => token}) do
    with {:ok, _} <- Actions.fetch(id), true <- is_binary(token) and byte_size(token) <= 128 do
      conn
      |> put_session(:verification_link, %{"id" => id, "token" => token})
      |> redirect(to: page_path(id))
    else
      _ -> failure(conn)
    end
  end
  def email_link(conn, _), do: failure(conn)

  @doc "Displays the gate or final confirmation from trusted session state."
  def show(conn, %{"id" => id}), do: show_page(conn, id)

  @doc "Handles a CSRF-protected form submission; email redemption never executes the action."
  def update(conn, %{"id" => id, "step" => step} = params) do
    account_id = current_account_id(conn)
    proof = get_session(conn, :sudo_proof)

    result =
      case step do
        "email" -> send_email(conn, id, account_id)
        "password" ->
          with :ok <- limit(conn, :verification_password, account_id, 60_000, 5) do
            Actions.verify_password(id, account_id, get_in(params, ["verification", "password"]))
          end
        "redeem" ->
          with %{"id" => ^id, "token" => token} <- get_session(conn, :verification_link),
               :ok <- limit(conn, :verification_token, id, 60_000, 10) do
            Actions.redeem(id, token, account_id)
          else
            {:error, reason} -> {:error, reason}
            _ -> {:error, :invalid_link}
          end
        "confirm" -> confirm_action(id, proof, account_id)
        "cancel" -> Actions.cancel(id, proof, account_id)
        _ -> {:error, :not_allowed}
      end

    case {step, result} do
      {step, {:ok, proof}} when step in ["password", "redeem"] ->
        conn
        |> configure_session(renew: true)
        |> delete_session(:verification_link)
        |> put_session(:sudo_proof, proof)
        |> redirect(to: page_path(id))

      {"email", {:ok, _}} -> show_page(conn, id, :sent)
      {"confirm", {:ok, success}} ->
        conn
        |> delete_session(:sudo_proof)
        |> delete_session(:verification_link)
        |> render_page(:done, success)

      {"cancel", {:ok, _}} ->
        conn
        |> delete_session(:verification_link)
        |> delete_session(:sudo_proof)
        |> render_page(:cancelled, %{title: l("Request cancelled"), description: l("This request has been cancelled. No action was taken.")})

      {_, {:error, :rate_limited}} -> failure(conn, :rate_limited)
      {"password", {:error, _}} -> show_page(conn, id, :password, l("That password didn’t match. Try again, or verify by email."))
      {"email", {:error, _}} -> show_page(conn, id, :verify, l("We couldn’t send the email. Please try again later."))
      {"confirm", {:error, :needs_reauth}} -> show_page(conn, id, :verify, l("Your verification has expired. Please verify again."))
      _ -> failure(conn)
    end
  end

  defp protect_verification_response(conn, _opts) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
  end

  defp confirm_action(id, proof, account_id) do
    with {:ok, pending} <- Actions.fetch(id),
         {:ok, module, context} <- Actions.context(pending),
         description = module.describe(context),
         {:ok, _} <- Actions.confirm(id, proof, account_id) do
      {:ok, description.success}
    end
  end

  defp send_email(conn, id, account_id) do
    with true <- is_binary(account_id),
         :ok <- limit(conn, :verification_email, account_id, 60_000, 1),
         :ok <- limit(conn, :verification_email_hour, account_id, 3_600_000, 10),
         {:ok, {pending, account, token}} <- Actions.issue_email(id, account_id),
         {:ok, module, context} <- Actions.context(pending) do
      url = Bonfire.Common.URIs.base_url() <> page_path(id) <> "/email?token=" <> token
      mail = Bonfire.Me.Mails.verification_link(account, url, module.describe(context).title)
      Bonfire.Me.Mails.mailer().send_now(mail, account.email.email_address)
    else
      {:error, _} = error -> error
      _ -> {:error, :not_allowed}
    end
  end

  defp show_page(conn, id, requested_state \\ nil, error \\ nil) do
    account_id = current_account_id(conn)
    proof = get_session(conn, :sudo_proof)
    link = get_session(conn, :verification_link)

    with {:ok, pending} <- Actions.fetch(id),
         {:ok, module, context} <- Actions.context(pending) do
      fresh = Actions.fresh?(proof, pending, account_id)
      has_link = is_map(link) and link["id"] == id
      owner = account_id == pending.account_id
      state = cond do
        not is_nil(account_id) and not owner -> :mismatch
        fresh -> :confirm
        has_link -> :link
        owner -> requested_state || :verify
        true -> :expired
      end

      if state == :expired do
        render_page(conn, :expired, %{
          title: l("Verification required"),
          description: l("Your verification has expired or is unavailable in this browser. No action was taken. Return to the browser where you started and request another email, or sign in to start again.")
        })
      else
        account = repo().preload(context.account, [:email, :credential])
        render_page(conn, state, module.describe(context),
          id: id, error: error,
          email: if(owner, do: e(account, :email, :email_address, ""), else: ""),
          has_password: owner and Bonfire.Me.Accounts.account_has_password?(account))
      end
    else
      _ -> failure(conn)
    end
  end

  defp limit(conn, prefix, account_id, duration, count) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    with :ok <- Bonfire.UI.Common.RateLimit.check(prefix, "account:#{account_id}", duration, count),
         :ok <- Bonfire.UI.Common.RateLimit.check(prefix, "ip:#{ip}", duration, count * 5) do
      :ok
    else
      _ -> {:error, :rate_limited}
    end
  end

  defp failure(conn, reason \\ :expired) do
    description =
      case reason do
        :rate_limited ->
          %{title: l("Too many attempts"), description: l("Please wait before trying again.")}

        :needs_reauth ->
          %{title: l("Sign in to continue"), description: l("Sign in to start a new verification request.")}

        _ ->
          %{title: l("This request is no longer available"), description: l("The link may be invalid, expired or already used.")}
      end

    render_page(conn, :expired, description)
  end

  defp render_page(conn, state, description, opts \\ []) do
    conn
    |> assign(:force_static, true)
    |> live_render(AccountVerificationViewLive, session: %{
      "state" => state, "description" => description,
      "id" => opts[:id], "action" => opts[:action],
      "email" => opts[:email], "has_password" => opts[:has_password] || false,
      "error" => opts[:error]
    })
  end

  defp page_path(id), do: "/account/verify/" <> id
end
