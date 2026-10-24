defmodule Bonfire.UI.Me.FamiliarFollowersLiveTest do
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  doctest Bonfire.UI.Me.FamiliarFollowersLive, only: [parts: 2], import: true
end
