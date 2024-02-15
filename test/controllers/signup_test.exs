defmodule Bonfire.UI.Me.SignupController.Test do
  use Bonfire.UI.Me.ConnCase, async: true

  test "form renders" do
    conn = conn()
    conn = get(conn, "/signup")
    doc = floki_response(conn)
    assert [form] = Floki.find(doc, "#signup-form")
    assert [_] = Floki.find(form, "input[type='email']")
    assert [_, _] = Floki.find(form, "input[type='password']")
    assert [_] = Floki.find(form, "button[type='submit']")
  end

  describe "required fields" do
    test "missing both" do
      conn = conn()
      conn = post(conn, "/signup", %{"account" => %{}})
      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [form] = Floki.find(signup, "#signup-form")
      assert [_] = Floki.find(form, "input[type='email']")
      assert [_, _] = Floki.find(form, "input[type='password']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing password" do
      conn = conn()
      email = email()

      conn =
        post(conn, "/signup", %{
          "account" => %{"email" => %{"email_address" => email}}
        })

      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [form] = Floki.find(signup, "#signup-form")
      assert [_, _] = Floki.find(form, "input[type='password']")

      # assert [password_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='signup-form_password']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end

    test "missing email" do
      conn = conn()
      password = password()

      conn =
        post(conn, "/signup", %{
          "account" => %{"credential" => %{"password" => password}}
        })

      doc = floki_response(conn)
      assert [signup] = Floki.find(doc, "#signup")
      assert Floki.text(signup) =~ "error occurred"
      assert [form] = Floki.find(signup, "#signup-form")
      assert [_] = Floki.find(form, "input[type='email']")

      # assert [email_error] = Floki.find(form, "span.invalid-feedback[phx-feedback-for='signup-form_email']")
      assert [_] = Floki.find(form, "button[type='submit']")
    end
  end

  test "success" do
    conn = conn()
    email = email()
    password = password()

    conn =
      post(conn, "/signup", %{
        "account" => %{
          "email" => %{"email_address" => email},
          "credential" => %{"password" => password}
        }
      })

    doc = floki_response(conn)
    assert [signup] = Floki.find(doc, "#signup")
    assert [p] = Floki.find(doc, "[data-id=confirmation_success]")
    assert Floki.text(p) =~ ~r/confirm your email/s
    assert [] = Floki.find(doc, "#signup-form")
  end

  test "success (with PhoenixTest)" do
    conn = conn()
    email = email()
    password = password()

    # IO.inspect(conn.assigns, label: "asssss")

    pt =
      conn
      |> visit("/")

    IO.inspect(pt.view)

    pt
    |> click_link("Create an account")
    |> assert_has("button", "Accept")
    # |> click_button("Accept") # powered by Alpine.JS 
    # |> assert_has("form#signup-form")
    |> submit_form("form#signup-form",
      account: %{
        # email_address: email
        email: %{email_address: email}, 
        # credential: %{password: password}
      }
      # %{
      #     "name='account[email][email_address]'" => email,
      #     "name='account[credential][password]'" => password
      #   }
      # %{
      #   "account[email][email_address]" => email,
      #   "account[credential][password]" => password
      # }
      # %{
      #     "account" => %{
      #       "email" => %{"email_address" => email},
      #       "credential" => %{"password" => password}
      #     }
      #   }
      # account: [
      #   email: [email_address: email], 
      #   credential: [password: password]
      # ]
    )
    # |> submit_form("form#signup-form", %{})
    # FIXME: `element selected by "#signup-form" does not have phx-submit attribute`
    # |> click_button("Sign up")
    # TODO
    |> assert_has(".current_account", "me")
  end
end
