# Replaced by `Bonfire.UI.Me.DashboardSettingsLive` with `scope: :instance`, the same page users have for their own dashboard. Its template sets 3 keys nothing reads (`:trending_links`, `:instance_status`, `:user_status`); the dashboard's sidebar toggles come back with the sidebar's own widget settings.
# defmodule Bonfire.UI.Me.SettingsViewsLive.DashboardSettingsLive do
#   use Bonfire.UI.Common.Web, :stateless_component
#
#   prop selected_tab, :any
#   prop scope, :atom, default: nil
# end
