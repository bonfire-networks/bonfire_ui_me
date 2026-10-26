defmodule Bonfire.UI.Me.FamiliarFollowersLiveTest do
  @moduledoc """
  Compares the rendered text with whitespace collapsed, as a browser shows it: the Surface formatter once deleted the names from a one-line template.
  """
  use Bonfire.UI.Me.ConnCase, async: System.get_env("TEST_UI_ASYNC") != "no"

  import Phoenix.LiveViewTest

  alias Bonfire.UI.Me.FamiliarFollowersLive

  doctest FamiliarFollowersLive, only: [sentence: 2], import: true

  setup do
    {:ok, people: for(_ <- 1..2, do: fake_user!())}
  end

  for size <- [:hero, :card] do
    test "#{size}: one person", %{people: [ana | _]} do
      assert sentence([ana], 1, unquote(size)) == "Followed by #{ana.profile.name}"
    end

    test "#{size}: two people", %{people: [ana, bo]} do
      assert sentence([ana, bo], 2, unquote(size)) ==
               "Followed by #{ana.profile.name} and #{bo.profile.name}"
    end

    test "#{size}: two named, three others", %{people: [ana, bo]} do
      assert sentence([ana, bo], 5, unquote(size)) ==
               "Followed by #{ana.profile.name}, #{bo.profile.name} and 3 others you follow"
    end
  end

  test "the profile header links each name to the profile; the card doesn't", %{people: [ana | _]} do
    assert [_] = render([ana], 1, :hero) |> Floki.find("[data-role=familiar_followers_text] a")
    assert [] = render([ana], 1, :card) |> Floki.find("[data-role=familiar_followers_text] a")
  end

  # raw HTML: Floki drops whitespace-only text nodes
  defp sentence(users, total, size) do
    [_, inner] =
      Regex.run(
        ~r/data-role="familiar_followers_text"[^>]*>(.*?)<\/p>/s,
        html(users, total, size)
      )

    inner
    # debug-annotation comments
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/<[^>]*>/, "")
    # decode entities
    |> Floki.parse_fragment!()
    |> Floki.text()
    # collapse whitespace like a browser
    |> String.split()
    |> Enum.join(" ")
  end

  defp render(users, total, size), do: html(users, total, size) |> Floki.parse_fragment!()

  defp html(users, total, size) do
    render_component(&FamiliarFollowersLive.render/1, %{
      users: users,
      total: total,
      size: size,
      parent_id: "familiar_followers_test",
      __context__: %{}
    })
  end
end
