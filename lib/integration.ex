defmodule Bonfire.UI.Me do
  @moduledoc "./README.md" |> File.stream!() |> Enum.drop(1) |> Enum.join()
  use Bonfire.Common.Config

  def repo, do: Bonfire.Common.Config.repo()
  def mailer, do: Bonfire.Common.Config.get!(:mailer_module)
end
