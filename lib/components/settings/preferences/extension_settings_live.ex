defmodule Bonfire.UI.Me.ExtensionSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop extension, :any
  prop scope, :atom, default: nil
  prop dep, :map, default: nil

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])
    all_extensions = cached_data()

    dep = find_dep_by_app_name(all_extensions[:ui], assigns[:extension])

    if is_nil(dep) or not is_struct(dep, Mix.Dep) do
      dep = find_dep_by_app_name(all_extensions[:feature_extensions], assigns[:extension])
    end

    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      assigns
      |> assign(page_title: "Extension")
      |> assign(dep: dep)
      |> assign(scoped: scoped)
      |> render_sface()
    end
  end

  def cached_data, do: Cache.maybe_apply_cached({Bonfire.Common.Extensions, :data}, [])

  def find_dep_by_app_name(deps, app_name) do
    Enum.find(deps, fn dep -> dep.app == app_name end)
  end
end
