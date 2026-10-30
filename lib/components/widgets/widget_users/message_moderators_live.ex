defmodule Bonfire.UI.Me.MessageModeratorsLive do
  @moduledoc """
  A button to message all the people who can moderate the instance at once, and not pick one of them.

  It opens the message composer addressed to the instance's federation bot, labelled "The moderators of this instance": a message to the bot reaches them all (`Bonfire.Messages.send/3`). Someone not logged in gets a remote interaction link, as for the reply button and the "Send a message" item of a profile, to message the bot from their own instance.
  """
  use Bonfire.UI.Common.Web, :stateless_component

  prop class, :css_class, default: "btn btn-sm btn-outline border-divider normal-case gap-2"

  def render(assigns) do
    bot = bot()

    assigns
    |> assign(:bot_id, id(bot))
    |> assign(:bot_url, if(bot, do: URIs.canonical_url(bot)))
    |> render_sface()
  end

  # made if it is not there yet: the composer needs a recipient that exists
  defp bot do
    maybe_apply(
      Bonfire.Federate.ActivityPub.AdapterUtils,
      :get_or_create_service_character,
      [],
      fallback_return: nil
    )
  end
end
