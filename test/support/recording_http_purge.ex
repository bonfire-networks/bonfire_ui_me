defmodule Bonfire.UI.Me.Test.RecordingHTTPPurge do
  @moduledoc "An HTTP cache purge adapter for tests: sends what it's asked to purge to the process registered as `:widgets_http_purge_test`."
  @behaviour Bonfire.Common.Cache.HTTPPurge

  def bust_urls(urls), do: report({:bust_urls, urls})
  def bust_tags(tags), do: report({:bust_tags, tags})

  defp report(message) do
    case Process.whereis(:widgets_http_purge_test) do
      nil -> :ok
      pid -> send(pid, message) && :ok
    end
  end
end
