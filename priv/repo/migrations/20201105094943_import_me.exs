defmodule Bonfire.UI.Me.Repo.Migrations.ImportMe do
  use Ecto.Migration

  import Bonfire.UI.Me.Migration
  # accounts & users

  def change, do: migrate_me
end
