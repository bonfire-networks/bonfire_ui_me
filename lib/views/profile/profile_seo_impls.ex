alias Bonfire.UI.Me.ProfileSEO

defimpl SEO.Site.Build, for: Bonfire.Data.Identity.User do
  def build(user, _conn) do
    SEO.Site.build(
      title: ProfileSEO.title(user),
      description: ProfileSEO.description(user)
    )
  end
end

defimpl SEO.OpenGraph.Build, for: Bonfire.Data.Identity.User do
  use Bonfire.UI.Common

  def build(user, _conn) do
    SEO.OpenGraph.build(
      title: ProfileSEO.title(user),
      description: ProfileSEO.description(user),
      url: Bonfire.Common.URIs.canonical_url(user, preload_if_needed: false),
      image: ProfileSEO.image(user),
      type: :profile,
      detail: SEO.OpenGraph.Profile.build(username: e(user, :character, :username, nil))
    )
  end
end

defimpl SEO.Twitter.Build, for: Bonfire.Data.Identity.User do
  def build(user, _conn) do
    image = ProfileSEO.image(user)

    SEO.Twitter.build(
      title: ProfileSEO.title(user),
      description: ProfileSEO.description(user),
      image: image,
      card: if(image, do: :summary_large_image, else: :summary)
    )
  end
end
