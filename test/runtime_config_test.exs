defmodule Bonfire.UI.Me.RuntimeConfigTest do
  @moduledoc """
  Tests for `Bonfire.UI.Me.RuntimeConfig.profile_complete?/1`, which decides whether the getting-started widget still asks somebody to fill in their profile.
  """
  use Bonfire.UI.Me.DataCase, async: true

  alias Bonfire.UI.Me.RuntimeConfig

  describe "profile_complete?/1" do
    test "is false for a brand-new user without a picture or anything written" do
      refute RuntimeConfig.profile_complete?(Bonfire.Me.Fake.fake_user!())
    end

    test "is false for nothing at all" do
      refute RuntimeConfig.profile_complete?(nil)
    end

    test "is true for a user with both a picture and a summary" do
      assert RuntimeConfig.profile_complete?(%{
               profile: %{summary: "who I am", icon_id: "01H0000000000000000000000"}
             })
    end

    test "counts an icon loaded as a struct rather than only an id" do
      assert RuntimeConfig.profile_complete?(%{
               profile: %{summary: "who I am", icon: %{url: "/images/me.png"}}
             })
    end

    test "is false with a picture but nothing written" do
      refute RuntimeConfig.profile_complete?(%{
               profile: %{summary: "", icon_id: "01H0000000000000000000000"}
             })

      refute RuntimeConfig.profile_complete?(%{
               profile: %{summary: "   ", icon_id: "01H0000000000000000000000"}
             })
    end

    test "is false with something written but no picture" do
      refute RuntimeConfig.profile_complete?(%{profile: %{summary: "who I am"}})
    end
  end
end
