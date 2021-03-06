defmodule Bonfire.UI.Me.ProfileRemoteFollowLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop page_title, :string, required: true
  prop page, :string, required: true
  prop selected_tab, :string, default: "timeline"
  prop smart_input, :boolean, required: true
  prop smart_input_prompt, :string
  prop smart_input_text, :string
  prop search_placeholder, :string
  prop feed_title, :string
  prop user, :map
  prop follows_me, :boolean, default: false

  slot header

end
