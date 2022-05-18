Code.eval_file("mess.exs")
defmodule Bonfire.UI.Me.MixProject do

  use Mix.Project

  def project do
    [
      app: :bonfire_ui_me,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: Mess.deps([
        {:phoenix_live_reload, "~> 1.2", only: :dev},
        {:dbg, "~> 1.0", only: [:dev, :test]},
        {:bonfire_editor_ck, git: "https://github.com/bonfire-networks/bonfire_editor_ck", branch: "main", optional: true},
        {:bonfire_editor_quill, git: "https://github.com/bonfire-networks/bonfire_editor_quill", branch: "main", optional: true},
        {:bonfire_tag, git: "https://github.com/bonfire-networks/bonfire_tag", branch: "main", optional: true},
        {:bonfire_social, git: "https://github.com/bonfire-networks/bonfire_social", branch: "main", optional: true}
        # {:bonfire_valueflows, "https://github.com/bonfire-networks/bonfire_valueflows", branch: "main", optional: true}
        # {:bonfire_ui_valueflows, "https://github.com/bonfire-networks/bonfire_ui_valueflows", branch: "main", optional: true}
      ]),
      package: [
        licenses: ["AGPL v3"]
      ]
    ]
  end

  def application, do: [ extra_applications: [:logger, :runtime_tools] ]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]


  defp aliases do
    [
      "hex.setup": ["local.hex --force"],
      "rebar.setup": ["local.rebar --force"],
      "js.deps.get": ["cmd npm install --prefix assets"],
      "ecto.seeds": ["run priv/repo/seeds.exs"],

      setup: ["hex.setup", "rebar.setup", "deps.get", "ecto.setup", "js.deps.get"],
      updates: ["deps.get", "ecto.migrate", "js.deps.get"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "ecto.seeds"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

end
