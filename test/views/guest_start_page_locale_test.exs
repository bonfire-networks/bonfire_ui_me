defmodule Bonfire.Web.Views.GuestStartPageLocaleTest do
  @moduledoc """
  The logged-out start page and the login errors in a language other than English.

  The fixture language is Italian (`it` is one of the test locales): "Sign in" and "About Bonfire" are translated in `bonfire_ui_common`, "Groups" in `bonfire_ui_common` and `bonfire_ui_groups`, "Spotlight" in `bonfire_ui_me`.
  """
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Common.Localise
  alias Bonfire.Social.Pins

  setup do
    on_exit(fn -> Localise.put_locale("en") end)

    # both loaders are cached for hours: start every test from the current DB state
    Bonfire.Me.Users.list_declared_moderators(cache: :reset)
    Pins.list_spotlight_activities(cache: :reset)
    Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)

    admin = fake_admin!(fake_account!())
    Pins.pin(admin, publish!(admin, "a public post in the guest spotlight"), :instance)
    Pins.list_spotlight_activities(cache: :reset)

    Bonfire.Classify.Simulate.fake_group!(admin, %{
      name: "Guest visible group",
      visibility: "global"
    })

    Bonfire.UI.Groups.WidgetGroupsCarouselLive.list_guest_groups(cache: :reset)

    :ok
  end

  defp publish!(user, body) do
    {:ok, post} =
      Bonfire.Posts.publish(
        current_user: user,
        post_attrs: %{post_content: %{html_body: body}},
        boundary: "public"
      )

    post
  end

  # The page as the guest's browser gets it: the first render, in the request's own process. `visit/2` would also connect the LiveView, and that second mount has no `Accept-Language` (guests are cookieless), so it renders in the instance language and says nothing about what a guest sees.
  defp italian_guest_page(path \\ "/") do
    Localise.put_locale("en")

    conn()
    |> Plug.Conn.put_req_header("accept-language", "it")
    |> get(path)
    |> html_response(200)
    |> Floki.parse_document!()
  end

  defp text_at(doc, selector), do: doc |> Floki.find(selector) |> Floki.text() |> String.trim()

  describe "guest start page, browser language Italian" do
    test "control: the page is rendered in Italian at all, by a string no app template owns" do
      doc = italian_guest_page()
      assert Floki.attribute(doc, "html", "lang") == ["it"]
      assert text_at(doc, "#guest-board-signin") == "Accedi"
    end

    test "Sign in is translated in the hero, the masthead and the mobile dock" do
      doc = italian_guest_page()
      assert text_at(doc, "#hero-login") == "Accedi"
      assert text_at(doc, "#guest-board-signin") == "Accedi"
      assert text_at(doc, "#dock-login-action") == "Accedi"
    end

    test "the Spotlight heading is translated" do
      assert text_at(italian_guest_page(), "#guest-spotlight [data-role=widget-heading]") ==
               "Vetrina"
    end

    test "the Groups heading is translated" do
      assert text_at(italian_guest_page(), "#guest-groups [data-role=widget-heading]") ==
               "Gruppi"
    end

    # TODO: no locale has a real translation of "Community Chat" yet (the `it` one was written by hand), prove it through a test catalogue or a real translation
    @tag :todo
    test "the About Bonfire and Community Chat links are translated, and keep their URLs" do
      about = "https://bonfirenetworks.org/"
      chat = "https://matrix.to/#/%23bonfire-networks:matrix.org"

      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"About Bonfire", about},
        {"Community Chat", chat}
      ])

      doc = italian_guest_page()
      assert text_at(doc, "#community-links a[href='#{about}']") == "Informazioni su Bonfire"
      assert text_at(doc, "#community-links a[href='#{chat}']") == "Chat della comunità"
      assert text_at(doc, "#guest-board-footer a[href='#{chat}']") == "Chat della comunità"
    end

    test "control: a link name the instance chose itself is left as written" do
      Process.put([:bonfire, :ui, :theme, :instance_welcome, :links], [
        {"Forum of the island", "https://forum.example/"}
      ])

      assert text_at(
               italian_guest_page(),
               "#community-links a[href='https://forum.example/']"
             ) == "Forum of the island"
    end
  end

  describe "login errors, browser language Italian" do
    defp render_errors(error) do
      Localise.put_locale("it")

      render_component(&Bonfire.UI.Me.LoginErrorsLive.render/1,
        form: %{errors: %{form: {error, []}}},
        error: nil,
        __context__: %{}
      )
      |> Floki.parse_fragment!()
    end

    # TODO: the msgid is new, so no locale has a real translation yet (the `it` one was written by hand), prove it through a test catalogue or a real translation
    @tag :todo
    test "the sign up sentence is one string with the link inside" do
      html = render_errors("not_found")
      [link] = Floki.find(html, "a")

      assert Floki.attribute(link, "href") == [Bonfire.Common.URIs.path(:signup)]
      assert link |> Floki.text() |> String.trim() == "registrarti"

      assert html |> Floki.text() |> String.replace(~r/\s+/, " ") |> String.trim() ==
               "Account non trovato. Il nome utente o la password non erano corretti. Vuoi registrarti?"
    end

    # TODO: the msgid is new, so no locale has a real translation yet (the `it` one was written by hand), prove it through a test catalogue or a real translation
    @tag :todo
    test "the resend sentence is one string with the link inside, without the 'to to' typo" do
      html = render_errors("email_not_confirmed")
      [link] = Floki.find(html, "a")

      assert Floki.attribute(link, "href") ==
               [Bonfire.Common.URIs.path(Bonfire.UI.Me.ConfirmEmailController)]

      assert link |> Floki.text() |> String.trim() == "reinviata"

      assert html |> Floki.text() |> String.replace(~r/\s+/, " ") |> String.trim() ==
               "Devi fare clic sul link nell'email che dovresti aver ricevuto per verificare il tuo indirizzo email. Vuoi che ti venga reinviata?"
    end

    test "control: in English the link is still in the sentence, once, with no doubled word" do
      Localise.put_locale("en")

      html =
        render_component(&Bonfire.UI.Me.LoginErrorsLive.render/1,
          form: %{errors: %{form: {"email_not_confirmed", []}}},
          error: nil,
          __context__: %{}
        )
        |> Floki.parse_fragment!()

      assert [link] = Floki.find(html, "a")
      assert link |> Floki.text() |> String.trim() == "resent"
      text = html |> Floki.text() |> String.replace(~r/\s+/, " ")
      refute text =~ "to to"
      assert text =~ "Need to have it resent?"
    end
  end
end
