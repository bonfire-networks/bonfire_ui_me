defmodule Bonfire.UI.Me.ForgotPasswordController.Test do
  # async: false so the global `:login_email_providers` config swap below
  # doesn't leak into other tests.
  use Bonfire.UI.Me.ConnCase, async: false

  alias Bonfire.Me.Accounts

  # Records every call so the test can inspect it.
  defmodule RecordingProvider do
    @behaviour Bonfire.UI.Me.LoginEmailProvider

    def start do
      case Process.whereis(__MODULE__) do
        nil -> Agent.start(fn -> [] end, name: __MODULE__)
        _ -> :ok
      end
    end

    def calls, do: Agent.get(__MODULE__, & &1)
    def reset, do: Agent.update(__MODULE__, fn _ -> [] end)

    @impl true
    def ensure_account(email) do
      Agent.update(__MODULE__, &[email | &1])
      :no_match
    end
  end

  setup do
    RecordingProvider.start()
    RecordingProvider.reset()
    original = Application.get_env(:bonfire_ui_me, :login_email_providers, [])
    Application.put_env(:bonfire_ui_me, :login_email_providers, [RecordingProvider])

    on_exit(fn ->
      Application.put_env(:bonfire_ui_me, :login_email_providers, original)
      if pid = Process.whereis(RecordingProvider), do: Agent.stop(pid)
    end)

    :ok
  end

  test "unknown email triggers registered login email providers" do
    email = "unknown-#{System.unique_integer([:positive])}@example.com"

    post(conn(), "/login/forgot-password", %{"forgot_password_fields" => %{"email" => email}})

    assert [^email] = RecordingProvider.calls()
  end

  test "known email does NOT trigger login email providers" do
    account = fake_account!()
    email = account.email.email_address

    post(conn(), "/login/forgot-password", %{"forgot_password_fields" => %{"email" => email}})

    assert [] = RecordingProvider.calls()
  end

  test "blank email does NOT call providers" do
    conn =
      post(conn(), "/login/forgot-password", %{"forgot_password_fields" => %{"email" => ""}})

    refute conn.status == 500
    assert [] = RecordingProvider.calls()
  end
end
