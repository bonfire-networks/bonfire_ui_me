defmodule Bonfire.UI.Me.CharacterLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  alias Bonfire.Me.Integration
  import Where

  # alias Bonfire.Me.Fake
  alias Bonfire.UI.Me.LivePlugs

  def mount(params, session, socket) do
    live_plug params, session, socket, [
      LivePlugs.LoadCurrentAccount,
      LivePlugs.LoadCurrentUser,
      # LivePlugs.LoadCurrentUserCircles,
      Bonfire.UI.Common.LivePlugs.StaticChanged,
      Bonfire.UI.Common.LivePlugs.Csrf,
      Bonfire.UI.Common.LivePlugs.Locale,
      &mounted/3
    ]
  end

  defp mounted(params, _session, socket) do
    # info(params)

    current_user = current_user(socket)
    current_username = e(current_user, :character, :username, nil)

    user_etc = case Map.get(params, "id") do
      nil ->
        current_user

      username when username == current_username ->
        current_user

      "@"<>username ->
        get(username)
      username ->
        get(username)
    end
    |> debug("user_etc")

    if user_etc do
      if Integration.is_local?(user_etc) do # redir to login and then come back to this page
        {:ok,
          socket
          |> redirect_to(path(user_etc))
        }
      else # redir to remote profile
        {:ok,
          socket
          |> redirect(external: canonical_url(user_etc))
        }
      end
    else
      {:ok,
        socket
        |> assign_flash(:error, l "Not found")
        |> redirect_to(path(:error))
      }
    end
  end

  def get(username) do
    username = String.trim_trailing(username, "@"<>Bonfire.Common.URIs.instance_domain())

    with {:ok, character} <- Bonfire.Me.Characters.by_username(username) do
      Bonfire.Common.Pointers.get!(character.id, skip_boundary_check: true) # FIXME? this results in extra queries
    else _ ->
      nil
    end
  end


end
