defmodule Bonfire.UI.Me.OrcidKeywordsLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop metadata, :map, required: true

  defp extract_keywords(metadata) do
    # Safely navigating through nested maps to find keywords
    metadata
    |> get_in(["orcid", "person", "keywords", "keyword"])
    |> Enum.map(fn %{"content" => content} -> content end)
  end
end
