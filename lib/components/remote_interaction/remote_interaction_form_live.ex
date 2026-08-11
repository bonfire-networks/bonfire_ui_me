defmodule Bonfire.UI.Me.RemoteInteractionFormLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop canonical_url, :string, required: true
  prop name, :string, required: true

  @doc "Untranslated slug naming the interaction: `follow`, `like`, `boost` or `flag`. It travels through a URL query param, so it must not be localised."
  prop interaction_type, :string, default: "follow"

  slot header

  @doc """
  The localised verb for an interaction slug.

  Delegates to `Bonfire.Boundaries.Verbs.verb_name/1`, which resolves the slug against the verb list and localises it in the `bonfire_boundaries` domain that declares it. That gives one canonical entry per verb, rather than each extension starting a remote interaction translating "follow" into its own domain.
  """
  def verb_name(slug) do
    # `Verbs.get/2` only resolves atoms, since it matches a string against the *localised* name;
    # `maybe_to_atom!/1` returns nil for anything not already an atom, so an unknown slug falls
    # through to itself rather than being silently rewritten to another verb
    Bonfire.Boundaries.Verbs.verb_name(Types.maybe_to_atom!(slug)) || slug
  end

  @doc """
  The submit button label, as one whole sentence per interaction.

  Only the button gets this treatment: it is short, the most visible string on the page, and the one where a spliced-in verb reads worst ("Proceed to suivre"). The longer paragraphs keep a `%{verb}` placeholder, since writing those out per interaction multiplies them for less gain.

  The last clause is the fallback for a slug we do not ship a sentence for, so an unknown interaction degrades to an interpolated verb rather than to nothing.
  """
  def submit_label("like"), do: l("Proceed to like")
  def submit_label("boost"), do: l("Proceed to boost")
  def submit_label("flag"), do: l("Proceed to flag")
  def submit_label("follow"), do: l("Proceed to follow")
  def submit_label(slug), do: l("Proceed to %{verb}", verb: verb_name(slug))
end
