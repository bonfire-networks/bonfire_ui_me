defmodule Bonfire.UI.Me.EmailLink do
  @moduledoc "What the views behind an emailed link (signup confirmation, magic-link sign-in, password reset) have in common."

  import Untangle

  # the query params of an emailed link that must survive from the page to the button's POST
  @carried_params ~w(go redirect_uri as_user)

  @doc """
  Renders the page an emailed link opens, with a button that posts back to `path`. The link's token is not used until that POST, so a mail scanner that only opens the link can't use it up.

  `path` is the link's own path. The `go`, `redirect_uri` and `as_user` query params of the request are added to the button's action, so they survive. Options are `:title`, `:intro` and `:button`, the page's texts.
  """
  def confirm_page(conn, path, opts) do
    query =
      conn
      |> Plug.Conn.fetch_query_params()
      |> Map.fetch!(:query_params)
      |> Map.take(@carried_params)
      |> Enum.filter(fn {_key, value} -> is_binary(value) and value != "" end)

    action = if query == [], do: path, else: path <> "?" <> URI.encode_query(query)

    Phoenix.LiveView.Controller.live_render(conn, Bonfire.UI.Me.ConfirmLinkLive,
      session: %{
        "title" => opts[:title],
        "intro" => opts[:intro],
        "button" => opts[:button],
        "action" => action
      }
    )
  end

  @doc """
  The page a link lands on when its token cannot be used: the form to ask for a new link, with the reason as an alert. `result` is what checking or using the token returned, and `kind` (`:sign_in` or `:reset`) is only for the log.

  The reason is one of `:expired` (never used, and out of time), `:used` (used before, and past its grace period) or `:invalid` (unknown, or replaced by a newer email). Only someone holding the token sees it, so it says nothing about which emails have an account.
  """
  def failure(conn, kind, result) do
    reason = failure_reason(result)
    log_link(conn, kind, reason)

    Phoenix.LiveView.Controller.live_render(conn, Bonfire.UI.Me.ForgotPasswordLive,
      session: %{"link_error" => reason}
    )
  end

  defp failure_reason({:error, :expired}), do: :expired
  defp failure_reason({:error, :already_confirmed}), do: :used
  defp failure_reason(_), do: :invalid

  @doc """
  One log line about an emailed link being opened, used or refused, so a report such as "my link expired" can be checked against what happened: the kind of link, the outcome, a short fingerprint of the token (never the token) and the user agent. Mail scanners open links, and their user agent tells them from a person.
  """
  def log_link(conn, kind, outcome) do
    token = conn.params["login_token"] || conn.params["id"] || ""
    fingerprint = :crypto.hash(:sha256, token) |> Base.encode16(case: :lower) |> binary_part(0, 8)
    user_agent = conn |> Plug.Conn.get_req_header("user-agent") |> List.first()

    info(
      "kind=#{kind} outcome=#{outcome} link=#{fingerprint} user_agent=#{inspect(user_agent)}",
      "email link"
    )

    conn
  end

  @doc """
  Keeps the `go` of an emailed link in the session as soon as the link is used, so it survives the whole sign-in or setup that follows, the switch-user and create-profile pages included.
  """
  def stash_go(conn) do
    conn = Plug.Conn.fetch_query_params(conn)
    go = conn.query_params["go"]

    if is_binary(go) and go != "", do: Bonfire.UI.Common.set_go_after(conn, go), else: conn
  end

  @doc """
  Whether a changeset only has errors on `:form`, such as "not_found" or "confirmation_disabled". The person typed a valid email address and we just won't email anyone. Callers answer exactly as if a link was sent, so nobody can tell who has an account. Errors on the `:email` field (bad format and so on) are not neutral, and keep showing the form.
  """
  def neutral_form_error?(%Ecto.Changeset{errors: errors}) when errors != [] do
    Enum.all?(errors, fn {field, _} -> field == :form end)
  end

  def neutral_form_error?(_), do: false
end
