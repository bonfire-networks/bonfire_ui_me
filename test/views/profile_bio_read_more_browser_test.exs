defmodule Bonfire.UI.Me.ProfileBioReadMoreBrowserTest do
  @moduledoc "A long bio is clamped on the user's profile, with Read more to show it whole, as a long post is. The clamp is CSS and JS, so this runs in a browser. Run with HOSTNAME=localhost and matching SERVER_PORT/PUBLIC_PORT values so the browser URL and socket origin use the test server."
  use ExUnit.Case, async: false

  alias Wallaby.{Browser, Query}
  require Browser
  import Wallaby.Browser, only: [execute_query: 2]
  alias Bonfire.Common.Repo

  @moduletag :ui
  @moduletag :browser
  if System.get_env("PHX_SERVER") not in ~w(yes true 1),
    do: @moduletag(skip: "Run with just test-ui-browser and a free SERVER_PORT")

  @endpoint Application.compile_env!(:bonfire, :endpoint_module)

  @password "profile-read-more-password"

  @hero "[data-id=profile_hero]"

  @long_bio Enum.map_join(1..30, "\n\n", &"Line #{&1} of a long bio.")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    {:ok, _} = Application.ensure_all_started(:wallaby)
    {:ok, session} = Wallaby.start_session()
    on_exit(fn -> Wallaby.end_session(session) end)

    account = Bonfire.Me.Fake.fake_account!(%{credential: %{password: @password}})
    viewer = Bonfire.Me.Fake.fake_user!(account)

    %{session: Browser.resize_window(session, 1440, 1000), viewer: viewer}
  end

  test "a user with a long bio shows Read more on their profile, which shows the last line", %{
    session: session,
    viewer: viewer
  } do
    user = Bonfire.Me.Fake.fake_user!(Bonfire.Me.Fake.fake_account!(), %{summary: @long_bio})

    session
    |> sign_in(viewer)
    |> Browser.visit(@endpoint.url() <> "/@#{user.character.username}")
    |> Browser.assert_has(Query.css(".phx-connected #{@hero}"))
    |> Browser.assert_has(Query.css("#{@hero} .read-more-btn", text: "Read more"))
    |> assert_shown(@hero, "Line 30 of", false, "control: the last line is clamped")
    |> Browser.click(Query.css("#{@hero} .read-more-btn"))
    |> assert_shown(@hero, "Line 30 of", true, "the last line is shown after Read more")
  end

  test "a user with a short bio shows no Read more", %{session: session, viewer: viewer} do
    user = Bonfire.Me.Fake.fake_user!(Bonfire.Me.Fake.fake_account!(), %{summary: "I knit."})

    session
    |> sign_in(viewer)
    |> Browser.visit(@endpoint.url() <> "/@#{user.character.username}")
    |> Browser.assert_has(Query.css(".phx-connected #{@hero}"))
    |> assert_shown(@hero, "I knit.", true, "the bio is shown")
    |> Browser.refute_has(Query.css("#{@hero} .read-more-btn", text: "Read more"))
  end

  defp sign_in(session, user) do
    session
    |> Browser.visit(@endpoint.url() <> "/login")
    |> Browser.fill_in(Query.fillable_field("login_fields[email_or_username]"),
      with: user.character.username
    )
    |> Browser.fill_in(Query.fillable_field("login_fields[password]"), with: @password)
    |> Browser.click(Query.css("#login_submit_btn"))
    |> Browser.assert_has(Query.css(".phx-connected #sidebar-feeds-link"))
  end

  # whether the paragraph holding `text` is laid out and not cut off by an element that clips its overflow (as a line clamp does), up to `within` (the page's own scroll container would clip a long text too), polled for up to 2 seconds as the hook settles after a click
  defp assert_shown(session, within, text, expected, message, tries \\ 20) do
    result = shown(session, within, text)

    cond do
      result == expected ->
        session

      tries > 1 ->
        Process.sleep(100)
        assert_shown(session, within, text, expected, message, tries - 1)

      true ->
        flunk("#{message}: expected shown? to be #{expected}, got #{inspect(result)}")
    end
  end

  defp shown(session, within, text) do
    Browser.execute_script(
      session,
      """
      const root = document.querySelector(arguments[0]);
      const line = root && [...root.querySelectorAll('p')].find(p => p.textContent.includes(arguments[1]));
      if (!line) return null;
      const rect = line.getBoundingClientRect();
      if (rect.height === 0) return false;
      for (let el = line.parentElement; el && el !== root.parentElement; el = el.parentElement) {
        if (getComputedStyle(el).overflowY !== 'visible' && rect.bottom > el.getBoundingClientRect().bottom + 1) return false;
      }
      return true;
      """,
      [within, text],
      &send(self(), {:shown, &1})
    )

    receive do
      {:shown, result} -> result
    end
  end
end
