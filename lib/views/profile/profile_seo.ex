defmodule Bonfire.UI.Me.ProfileSEO do
  @moduledoc """
  Builds meaningful page metadata (title, description, image) for user/character
  profile pages, so that sharing a profile to X, Mastodon, Slack, etc. shows the
  person's name, bio and picture instead of the generic instance defaults.

  Used by the `SEO.*.Build` protocol implementations in `profile_seo_impls.ex`.
  """
  use Bonfire.UI.Common

  @description_length 200

  @doc "Profile title, eg. `Jane Doe (@jane@instance)`, falling back to the username."
  def title(user) do
    name = e(user, :profile, :name, nil)
    username = username(user)

    cond do
      is_binary(name) and name != "" and is_binary(username) -> "#{name} (@#{username})"
      is_binary(name) and name != "" -> name
      is_binary(username) -> "@#{username}"
      true -> nil
    end
  end

  @doc "Profile bio as plain, truncated text, or a sensible fallback describing the profile."
  def description(user) do
    case e(user, :profile, :summary, nil) do
      summary when is_binary(summary) and summary != "" ->
        summary
        |> Text.text_only()
        |> Text.sentence_truncate(@description_length)

      _ ->
        name = e(user, :profile, :name, nil) || username(user)
        if name, do: l("Profile of %{name} on %{instance}", name: name, instance: instance_name())
    end
  end

  @doc "Absolute URL of the user's banner image (or avatar if no banner is set)."
  def image(user) do
    has_banner? = not is_nil(e(user, :profile, :image, nil))

    url = if has_banner?, do: Media.banner_url(user), else: Media.avatar_url(user)

    Bonfire.UI.Common.SEOImage.absolute_url(url)
  end

  defp username(user), do: e(user, :character, :username, nil)

  defp instance_name do
    Config.get([:ui, :theme, :instance_name], l("this instance"))
  end
end
