defmodule Bonfire.UI.Me.MessageModeratorsTest do
  @moduledoc """
  A button on the places that list the instance's moderators, to message them all at once and not pick one. It opens the message composer with the instance's federation bot as the recipient, labelled "The moderators of this instance": a message to the bot reaches whoever can moderate the instance (`Messages.send/3`).
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"
  @moduletag :ui

  test "As a user I can open a message to the instance's moderators from the About page" do
    account = fake_account!()
    me = fake_user!(account)
    _moderator = Bonfire.Me.Fake.instance_moderator!(fake_user!(fake_account!()))
    # the list the widget shows is cached
    Bonfire.Me.Users.list_declared_moderators(cache: :reset)

    # The composer is a separate LiveView, which a test cannot look into, so this checks what the button sends it: the bot as the recipient, under the label.
    bot_id = Bonfire.Federate.ActivityPub.AdapterUtils.service_character_id()

    conn(user: me, account: account)
    |> visit("/about")
    |> assert_has("[data-role=composer_button]", text: "Message the moderators")
    |> assert_has(
      "[data-role=composer_button][phx-click*='#{bot_id}'][phx-click*='The moderators of this instance']"
    )
  end

  # What a moderator sees on the notifications page, which applies more than the feed itself: the categories switched on, the audiences hidden.
  test "a message to the moderators is listed on the notifications page of someone who is an admin and a moderator" do
    # as the notifications tests do: the test default page size is 2, which would cut the list
    Process.put([:bonfire, :feed_live_update_many_preload_mode], :inline)
    Process.put([:bonfire, :default_pagination_limit], 10)

    account = fake_account!()
    {:ok, staff} = Bonfire.Me.Users.make_admin(fake_user!(account))
    Bonfire.Me.Fake.instance_moderator!(staff)
    sender = fake_user!(fake_account!())
    bot = Bonfire.Federate.ActivityPub.AdapterUtils.get_or_create_service_character()

    # prove the positive first: a post that names this user is on the page
    assert {:ok, _} =
             Bonfire.Posts.publish(
               current_user: sender,
               post_attrs: %{
                 post_content: %{
                   html_body: "a post for @#{staff.character.username}, to prove the page lists"
                 }
               },
               boundary: "public"
             )

    assert {:ok, _post} =
             Bonfire.Messages.send(sender, %{
               to_circles: [bot.id],
               post_content: %{html_body: "a question for the moderators"}
             })

    conn(user: staff, account: account)
    |> visit("/notifications")
    |> wait_async()
    |> assert_has("[data-id=feed]", text: "to prove the page lists")
    |> assert_has("[data-id=feed]", text: "a question for the moderators")
  end

  for page <- ["/", "/about"] do
    # as the reply and "Send a message" buttons of someone not logged in: a remote interaction, from their own instance
    test "a visitor who is not logged in gets a remote interaction link to message them, on #{page}" do
      _admin = fake_admin!(fake_account!())
      # the list the page shows is cached
      Bonfire.Me.Users.list_declared_moderators(cache: :reset)

      conn()
      |> visit(unquote(page))
      |> assert_has("#community-admins a[href^='/remote_interaction?type=message']",
        text: "Message the moderators"
      )
    end
  end
end
