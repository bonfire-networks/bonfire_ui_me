defmodule Bonfire.UI.Me.SignupLive do
  use Bonfire.UI.Common.Web, :surface_live_view_child
  # alias Bonfire.Me.Accounts
  alias Bonfire.UI.Me.SignupController

  # because this isn't a live link and it will always be accessed by a
  # guest, it will always be offline
  def mount(params, session, socket) do
    # debug(session, "session")
    {:ok, assign_defaults(socket, params, session)}
  end

  def assign_defaults(socket_or_assigns, params \\ %{}, session \\ %{}, opts \\ []) do
    form_key = Keyword.get(opts, :form_key, :form)

    # compute the instance's rules sections once, so the rules display component can reuse them
    # instead of re-loading, and it doubles as the "show rules?" guard (nil when none are set)
    instance_rules =
      case maybe_apply(Bonfire.CommunityRules, :get_instance_rules_sections, [],
             fallback_return: []
           ) do
        [] -> nil
        sections -> sections
      end

    socket_or_assigns
    |> assign_global(:current_url, "/signup")
    |> assign(:page, l("signup"))
    |> assign(:page_title, l("Sign up"))
    |> assign_new(:no_header, fn -> true end)
    |> assign_new(:without_sidebar, fn -> true end)
    |> assign_new(:without_secondary_widgets, fn -> true end)
    |> assign_new(:current_account, fn -> nil end)
    |> assign_new(:current_account_id, fn -> nil end)
    |> assign_new(:current_user, fn -> nil end)
    |> assign_new(:full_width, fn -> true end)
    |> assign_new(:current_user_id, fn -> nil end)
    |> assign_new(:open_id_provider, fn -> session["open_id_provider"] end)
    |> assign_global(:csrf_token, session["_csrf_token"])
    |> assign_new(:error, fn -> nil end)
    |> assign_new(form_key, fn -> SignupController.form_cs(session) end)
    |> assign(:invite, e(session, "invite", nil))
    |> assign_new(:go, fn -> e(params, "go", nil) || e(session, "go", nil) end)
    |> assign(:registered, e(session, "registered", nil))
    |> assign_new(:auth_second_factor_secret, fn ->
      session["auth_second_factor_secret"]
    end)
    |> assign(:auth_config, Config.get([:ui, :auth], []))
    |> assign(:instance_welcome, Config.get([:ui, :theme, :instance_welcome], []))
    |> assign(:home_page, Config.get(:home_page, :home))
    |> assign(:instance_rules, instance_rules)
  end
end
