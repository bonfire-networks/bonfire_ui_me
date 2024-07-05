defmodule Bonfire.UI.Me.ExtensionSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop extension, :any, required: true
  prop scope, :atom, default: nil
  prop dep, :map, default: nil

  def render(%{extension: extension} = assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])
    all_extensions = Bonfire.Common.Extensions.all_deps()

    dep = find_dep_by_app_name(all_extensions, extension)

    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      assigns
      |> assign(
        page_title: "Extension",
        dep: Map.put(dep || %{}, :extra, Bonfire.Common.ExtensionModule.extension(extension)),
        scoped: scoped
      )
      |> render_sface()
    end
  end

  def find_dep_by_app_name(deps, app_name) do
    Enum.find(deps, fn %{app: app} -> app == app_name end)
  end
end
