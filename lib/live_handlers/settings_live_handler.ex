defmodule Bonfire.Me.Settings.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  # import Bonfire.Boundaries.Integration

  def handle_event("set", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <- Map.drop(attrs, ["_target"]) |> Bonfire.Me.Settings.set(socket) do
      # debug(settings, "done")
      {:noreply,
          socket
          |> maybe_assign_context(settings)
          |> assign_flash(:info, "Settings saved :-)")
      }
    end
  end

  def handle_event("save", attrs, socket) when is_map(attrs) do
    with {:ok, settings} <- Map.drop(attrs, ["_target"]) |> Bonfire.Me.Settings.set(socket) do
      {:noreply,
          socket
          |> maybe_assign_context(settings)
          |> assign_flash(:info, "Settings saved :-)")
          |> redirect_to("/")
      }
    end
  end

    # LiveHandler
  def handle_event("set_locale", %{"locale" => locale}, socket) do

    Bonfire.Common.Localise.put_locale(locale)
    |> debug("set current UI locale")

    # then save to settings
    %{"Bonfire.Common.Localise.Cldr"=> %{"default_locale"=> locale}}
    |> handle_event("set", ..., socket)
  end

  defp maybe_assign_context(socket, %{assign_context: assigns}) do
    socket
    |> assign_global(assigns)
  end
  defp maybe_assign_context(socket, _), do: socket
end
