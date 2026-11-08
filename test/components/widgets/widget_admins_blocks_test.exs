defmodule Bonfire.UI.Me.WidgetAdminsBlocksTest do
  @moduledoc "The moderators widget lists the instance's moderators from one cache shared by everyone, minus those each viewer silenced."
  use Bonfire.UI.Me.ConnCase, async: false
  @moduletag :ui

  alias Bonfire.Boundaries.Blocks

  setup do
    account = fake_account!()
    me = fake_user!(account)
    silenced_admin = fake_admin!(fake_account!())
    other_admin = fake_admin!(fake_account!())

    Bonfire.Me.Users.list_declared_moderators(cache: :reset)
    on_exit(fn -> Bonfire.Me.Users.list_declared_moderators(cache: :reset) end)

    {:ok,
     conn: conn(user: me, account: account),
     me: me,
     silenced_admin: silenced_admin,
     other_admin: other_admin}
  end

  defp about(conn) do
    conn
    |> visit("/about")
    |> wait_async()
  end

  defp name(user), do: e(user, :profile, :name, nil)

  test "drops a moderator once I silence them, and keeps the others", %{
    conn: conn,
    me: me,
    silenced_admin: silenced_admin,
    other_admin: other_admin
  } do
    # the positive first, which also fills the shared cache
    about(conn)
    |> assert_has(".widget-users [data-role=widget-user-row]", text: name(silenced_admin))
    |> assert_has(".widget-users [data-role=widget-user-row]", text: name(other_admin))

    Blocks.block(silenced_admin, :silence, current_user: me)

    about(conn)
    |> assert_has(".widget-users [data-role=widget-user-row]", text: name(other_admin))
    |> refute_has(".widget-users [data-role=widget-user-row]", text: name(silenced_admin))
  end
end
