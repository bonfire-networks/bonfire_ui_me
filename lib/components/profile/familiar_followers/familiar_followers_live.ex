defmodule Bonfire.UI.Me.FamiliarFollowersLive do
  @moduledoc """
  "Followed by people you follow": a few overlapping avatars and a sentence naming up to two of them, then how many others. Shared by the profile header and the profile hover card, so they read the same.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  @doc "Up to three people the viewer follows who follow this user, with profiles loaded"
  prop users, :list, default: []

  @doc "How many such people there are in all; `nil` counts `users`"
  prop total, :integer, default: nil

  @doc "`:hero` (profile header: larger, names link to profiles) or `:card` (hover card: smaller, plain names)"
  prop size, :atom, default: :hero

  prop parent_id, :any, default: nil

  @doc """
  The sentence as a list of `{:text, string}` and `{:user, user}` parts, so the template can render names as links or plain text. Names fall back to the username.

      iex> parts([], 0)
      []

      iex> parts([%{profile: %{name: "Ana"}}], 1) |> to_text()
      "Followed by Ana"

      iex> parts([%{profile: %{name: "Ana"}}, %{profile: %{name: "Bo"}}], 2) |> to_text()
      "Followed by Ana and Bo"

      iex> parts([%{profile: %{name: "Ana"}}, %{profile: %{name: "Bo"}}, %{profile: %{name: "Cy"}}], 3) |> to_text()
      "Followed by Ana, Bo and 1 other you follow"

      iex> parts([%{profile: %{name: "Ana"}}, %{profile: %{name: "Bo"}}], 5) |> to_text()
      "Followed by Ana, Bo and 3 others you follow"

      iex> parts([%{profile: %{name: nil}, character: %{username: "ana"}}], 1) |> to_text()
      "Followed by ana"
  """
  def parts([], _total), do: []

  def parts(users, total) do
    shown = Enum.take(users, 2)
    others = (total || length(users)) - length(shown)
    names = shown |> Enum.map(&{:user, &1}) |> Enum.intersperse({:text, separator(others)})

    [{:text, l("Followed by") <> " "}] ++ names ++ others_part(others)
  end

  @doc "The sentence as plain text, for the doctests above"
  def to_text(parts) do
    parts
    |> Enum.map(fn
      {:text, text} -> text
      {:user, user} -> display_name(user)
    end)
    |> Enum.join()
  end

  defp display_name(user),
    do: e(user, :profile, :name, nil) || e(user, :character, :username, nil) || ""

  defp separator(0), do: " " <> l("and") <> " "
  defp separator(_others), do: ", "

  defp others_part(others) when others > 0,
    do: [
      {:text,
       " " <>
         lp("and %{count} other you follow", "and %{count} others you follow", others,
           count: others
         )}
    ]

  defp others_part(_), do: []
end
