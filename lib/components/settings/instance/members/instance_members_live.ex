defmodule Bonfire.UI.Me.SettingsViewsLive.InstanceMembersLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Ecto.Query

  prop show, :any, default: :local
  prop search_term, :string, default: ""
  prop title, :string, default: nil

  def update(assigns, socket) do
    socket = assign(socket, assigns)
    
    # Set page_title if title prop is provided
    if socket_connected?(socket) && e(assigns, :title, nil) do
      send_self(page_title: e(assigns, :title, nil))
    end

    {:ok,
     assign(
       socket,
       if(socket_connected?(socket),
         do: list_users(e(assigns(socket), :show, :local), e(assigns(socket), :search_term, "")),
         else: [users: [], page_info: nil]
       )
     )}
  end

  def handle_event("search", params, socket) do
    search_term = get_in(params, ["search_term"]) || ""

    # Only search if we have 3 or more characters, or if search is empty (to show all)
    should_search = String.length(String.trim(search_term)) >= 3 || String.trim(search_term) == ""
    
    if should_search do
      %{page_info: page_info, users: users} = list_users(
        e(assigns(socket), :show, :local),
        search_term
      )

      {:noreply,
       socket
       |> assign(
         search_term: search_term,
         users: users,
         page_info: page_info,
         loaded: true
       )}
    else
      # Just update the search term but don't search yet  
      {:noreply,
       socket
       |> assign(search_term: search_term)}
    end
  end

  def handle_event("load_more", attrs, socket) do
    # Load more only works without search
    if e(assigns(socket), :search_term, "") == "" do
      %{page_info: page_info, users: users} = list_users(
        e(assigns(socket), :show, :local),
        "",
        attrs
      )

      {:noreply,
       socket
       |> assign(
         loaded: true,
         users: users,
         page_info: page_info
       )}
    else
      # Don't paginate during search
      {:noreply, socket}
    end
  end

  def list_users(show, search_term \\ "", attrs \\ nil) do
    trimmed_search = String.trim(search_term)
    
    # Determine if we're searching
    is_searching = trimmed_search != "" and String.length(trimmed_search) >= 3
    
    {users, page_info} = if is_searching do
      # Use the search query directly to ensure associations are loaded
      query = Bonfire.Me.Users.Queries.search(trimmed_search)
      
      # Apply local/remote filter at the query level
      # Apply local/remote filter - joins may already exist from search query
      query = case show do
        :local ->
          # Filter for local users (no peered association)
          query
          |> join(:left, [character: c], p in assoc(c, :peered), as: :search_peered)
          |> where([search_peered: p], is_nil(p.id))
        :remote ->
          # Filter for remote users (has peered association)
          query
          |> join(:left, [character: c], p in assoc(c, :peered), as: :search_peered)
          |> where([search_peered: p], not is_nil(p.id))
        _ -> 
          query
      end
      
      # Execute query with error handling and result limiting
      users = 
        query
        |> limit(50)  # Limit search results to prevent performance issues
        |> Bonfire.Common.Repo.all()
        |> case do
          users when is_list(users) -> users
          _ -> []  # Return empty list on error
        end
      
      {users, nil}  # No pagination for search results
    else
      # No search, use regular list_paginated
      result = Bonfire.Me.Users.list_paginated(
        [show: show, skip_boundary_check: true, paginate: input_to_atoms(attrs)]
      )
      {result.edges, result.page_info}
    end

    # TODO: implement `Bonfire.Boundaries.Blocks.LiveHandler.update_many` so we don't do n+1 on these!
    users =
      Enum.map(users, fn user ->
        user
        |> Map.put(
          :ghosted_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(user, :ghost, :instance_wide)
        )
        |> Map.put(
          :silenced_instance_wide?,
          Bonfire.Boundaries.Blocks.is_blocked?(user, :silence, :instance_wide)
        )
      end)

    %{
      show: show,
      users: users,
      page_info: page_info
    }
  end
end
