defmodule Bonfire.UI.Me.ProfileLinksLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :any, default: nil
  prop user, :any, default: nil
  prop joined_date, :any, default: nil
  prop aliases, :any, default: []

  data links, :list, default: []
  data accounts, :list, default: []

  @doc false
  def render(assigns) do
    website = e(assigns[:user], :profile, :website, nil)
    {links, accounts} = group_links(website, assigns[:aliases])

    assigns
    |> assign(links: links, accounts: accounts)
    |> render_sface()
  end

  @doc """
  Groups displayable destinations so missing links do not leave empty sections.

  ## Examples

      iex> Bonfire.UI.Me.ProfileLinksLive.group_links("  ", [])
      {[], []}

      iex> Bonfire.UI.Me.ProfileLinksLive.group_links(" https://example.org ", nil)
      {[%{href: "https://example.org", label: nil, metadata: nil}], []}
  """
  def group_links(website, aliases) do
    links =
      case website do
        value when is_binary(value) -> [%{href: value, label: nil, metadata: nil}]
        _ -> []
      end

    {links, accounts} =
      Enum.reduce(aliases || [], {links, []}, fn
        %{edge: %{object: %{id: _, profile: profile, character: %{id: _}} = account}},
        {links, accounts}
        when not is_nil(profile) ->
          {links, accounts ++ [account]}

        %{edge: %{object: %{media_type: type, path: path, metadata: metadata}}},
        {links, accounts} ->
          href =
            if is_binary(path) and String.trim(path) != "",
              do: path,
              else: e(metadata, "url", nil)

          label = e(metadata, "name", nil) || if(is_binary(type), do: Text.upcase_first(type))
          {links ++ [%{href: href, label: label, metadata: metadata}], accounts}

        _, groups ->
          groups
      end)

    links =
      links
      |> Enum.filter(fn link -> is_binary(link.href) and String.trim(link.href) != "" end)
      |> Enum.map(fn link -> %{link | href: String.trim(link.href)} end)

    {links, accounts}
  end
end
