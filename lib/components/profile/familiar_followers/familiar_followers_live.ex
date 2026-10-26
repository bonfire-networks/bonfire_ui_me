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

  @doc false
  def render(assigns) do
    assigns
    |> assign(:sentence, sentence(assigns[:users] || [], assigns[:total]))
    |> render_sface()
  end

  @doc """
  The sentence as pieces joined by single spaces, so whatever whitespace the Surface formatter leaves between them reads right. Names fall back to the username.

      iex> sentence([], 0)
      nil

      iex> sentence([%{profile: %{name: "Ana"}}], 1) |> to_text()
      "Followed by Ana"

      iex> sentence([%{profile: %{name: "Ana"}}, %{profile: %{name: "Bo"}}], 2) |> to_text()
      "Followed by Ana and Bo"

      iex> sentence([%{profile: %{name: "Ana"}}, %{profile: %{name: "Bo"}}, %{profile: %{name: "Cy"}}], 3) |> to_text()
      "Followed by Ana, Bo and 1 other you follow"

      iex> sentence([%{profile: %{name: "Ana"}}, %{profile: %{name: "Bo"}}], 5) |> to_text()
      "Followed by Ana, Bo and 3 others you follow"

      iex> sentence([%{profile: %{name: "Ana"}}], 4) |> to_text()
      "Followed by Ana and 3 others you follow"

      iex> sentence([%{profile: %{name: nil}, character: %{username: "ana"}}], 1) |> to_text()
      "Followed by ana"
  """
  def sentence([], _total), do: nil

  def sentence(users, total) do
    shown = Enum.take(users, 2)
    others = (total || length(users)) - length(shown)

    names =
      shown
      |> Enum.with_index()
      |> Enum.map(fn
        # "Ana and Bo"
        {user, 1} when others == 0 -> %{before: l("and"), user: user, sep: ""}
        # "Ana, Bo and 3 others"
        {user, 0} when length(shown) == 2 and others > 0 -> %{before: nil, user: user, sep: ","}
        {user, _} -> %{before: nil, user: user, sep: ""}
      end)

    %{
      names: names,
      others:
        if(others > 0,
          do:
            lp("and %{count} other you follow", "and %{count} others you follow", others,
              count: others
            )
        )
    }
  end

  @doc "The sentence as plain text, for the doctests above"
  def to_text(nil), do: ""

  def to_text(%{names: names, others: others}) do
    names
    |> Enum.flat_map(&[&1.before, display_name(&1.user) <> &1.sep])
    |> then(&([l("Followed by")] ++ &1 ++ [others]))
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp display_name(user),
    do: e(user, :profile, :name, nil) || e(user, :character, :username, nil) || ""
end
