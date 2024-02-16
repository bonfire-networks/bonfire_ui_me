ExUnit.start(exclude: Bonfire.Common.RuntimeConfig.skip_test_tags())

repo = Bonfire.Common.Config.repo()

if GenServer.whereis(repo) do
  Ecto.Adapters.SQL.Sandbox.mode(
    repo,
    :manual
  )
end
