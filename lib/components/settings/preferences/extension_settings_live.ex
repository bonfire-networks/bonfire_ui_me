defmodule Bonfire.UI.Me.ExtensionSettingsLive do
  use Bonfire.UI.Common.Web, :stateful_component
  import Bonfire.Common.Extensions

  prop extension, :any, required: true
  prop scope, :atom, default: nil
  prop dep, :map, default: nil

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)

    {:ok,
     socket
     |> assign(prepare(assigns(socket)))}
  end

  # def render(assigns) do
  #   assigns
  #   |> assign(prepare())
  #   |> render_sface()
  # end

  def prepare(assigns) do
    if socket_connected?(assigns) do
      # Access directly from assigns
      extension = assigns.extension
      scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])

      if assigns[:scope] == :instance and
           Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
        raise Bonfire.Fail, :unauthorized
      else
        all_extensions = Bonfire.Common.Extensions.all_deps()
        dep = find_dep_by_app_name(all_extensions, extension)

        [
          page_title: "Extension",
          dep: Map.put(dep || %{}, :extra, Bonfire.Common.ExtensionModule.extension(extension)),
          scoped: scoped
        ]
      end
    else
      [
        page_title: l("Loading..."),
        dep: %{},
        scoped: nil
      ]
    end
  end

  def find_dep_by_app_name(deps, app_name) do
    Enum.find(deps, fn %{app: app} -> app == app_name end)
  end
end
