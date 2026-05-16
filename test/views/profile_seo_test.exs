defmodule Bonfire.UI.Me.ProfileSEOTest do
  use ExUnit.Case, async: true

  alias Bonfire.UI.Me.ProfileSEO

  describe "title/1" do
    test "combines name and username" do
      user = %{profile: %{name: "Jane Doe"}, character: %{username: "jane"}}
      assert ProfileSEO.title(user) == "Jane Doe (@jane)"
    end

    test "falls back to just the username" do
      user = %{profile: %{name: nil}, character: %{username: "jane"}}
      assert ProfileSEO.title(user) == "@jane"
    end

    test "uses the name alone when there is no username" do
      assert ProfileSEO.title(%{profile: %{name: "Jane"}}) == "Jane"
    end
  end

  describe "description/1" do
    test "uses the bio (as plain text) when present" do
      user = %{profile: %{summary: "<p>I build <b>things</b></p>"}}
      assert ProfileSEO.description(user) == "I build things"
    end

    test "falls back to a generated description mentioning the name" do
      user = %{profile: %{name: "Jane", summary: nil}, character: %{username: "jane"}}
      assert ProfileSEO.description(user) =~ "Jane"
    end
  end
end
