defmodule Bonfire.UI.Me.ExtensionSettingsLive do
  use Bonfire.UI.Common.Web, :stateless_component
  import Bonfire.Common.Extensions

  prop extension, :any
  prop scope, :atom, default: nil
  prop dep, :map, default: nil

  def render(assigns) do
    scoped = Bonfire.Common.Settings.LiveHandler.scoped(assigns[:scope], assigns[:__context__])
    all_extensions = cached_data()

    initial_dep = find_dep_by_app_name(all_extensions[:ui], assigns[:extension])
    IO.inspect(initial_dep, label: "Initial dep from UI extensions")

    final_dep =
      if is_nil(initial_dep) or not is_struct(initial_dep, Mix.Dep) do
        feature_dep =
          find_dep_by_app_name(all_extensions[:feature_extensions], assigns[:extension])

        IO.inspect(feature_dep, label: "Dep from feature extensions")
        feature_dep
      else
        initial_dep
      end

    IO.inspect(final_dep, label: "final Dep")

    if assigns[:scope] == :instance and
         Bonfire.Boundaries.can?(assigns[:__context__], :configure, :instance) != true do
      raise Bonfire.Fail, :unauthorized
    else
      assigns
      |> assign(page_title: "Extension")
      |> assign(dep: final_dep || %{})
      |> assign(scoped: scoped)
      |> render_sface()
    end
  end

  def cached_data, do: Cache.maybe_apply_cached({Bonfire.Common.Extensions, :data}, [])

  def find_dep_by_app_name(deps, app_name) do
    Enum.find(deps, fn dep -> dep.app == app_name end)
  end
end
