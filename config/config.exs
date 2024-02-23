import Config

import_config "bonfire_ui_me.exs"

config :needle, :search_path, [:bonfire_me]

# import_config "#{Mix.env()}.exs"

config_file = if Mix.env() == :test, do: "config/test.exs", else: "config/config.exs"

config :bonfire, Bonfire.Common.Repo, database: "bonfire_test"

cond do
  File.exists?("../bonfire/#{config_file}") ->
    IO.puts("Load #{config_file} from local clone of bonfire_spark")
    import_config "../../bonfire/#{config_file}"

  File.exists?("deps/bonfire/#{config_file}") ->
    IO.puts("Load #{config_file} from bonfire_spark dep")
    import_config "../deps/bonfire/#{config_file}"

  true ->
    IO.puts("No #{config_file} found")
    nil
end
