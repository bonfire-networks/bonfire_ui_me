defmodule Bonfire.UI.Me.DashboardSettingsLive do
  @moduledoc """
  Settings for the dashboard's widgets, as the dashboard's own edit mode, always on (`Bonfire.UI.Common.SettingsWidgetsLive`). A user's own, or with `scope: :instance` the defaults for everyone who hasn't set theirs.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop scope, :any, default: nil

  @doc "The view's `widgets_editing`, from `Bonfire.UI.Common.Widgets.LiveHandler.assign_settings_page/4`."
  prop widgets, :map, default: %{}
end
