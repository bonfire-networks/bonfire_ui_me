defmodule Bonfire.UI.Me.OrcidPreviewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop metadata, :map, required: true

  def total_peer_reviews(metadata) do
    metadata
    |> get_in(["orcid", "activities-summary", "peer-reviews", "group"]) # Get all peer-review groups
    |> Enum.reduce(0, fn group, acc ->
      # Sum the lengths of "peer-review-group" lists within each group
      group
      |> get_in(["peer-review-group"])
      |> Enum.count()
      |> Kernel.+(acc)
    end)
  end

  def total_publications_or_grants(metadata) do
    metadata
    |> get_in(["orcid", "activities-summary", "peer-reviews", "group"]) # Get all peer-review groups
    |> Enum.count() # Count each group as a distinct publication/grant
  end

  # def print_review_summary(metadata) do
  #   total_reviews = total_peer_reviews(metadata)
  #   total_publications = total_publications_or_grants(metadata)

  #   IO.puts("#{total_reviews} reviews for #{total_publications} publications/grants")
  # end

  def total_works(metadata) do
    metadata
    |> get_in(["orcid", "activities-summary", "works", "group"])
    |> Enum.count()
  end

end
