defmodule Bonfire.UI.Me.LoginErrorsLive do
  @moduledoc "Shows why a login attempt failed. Shared by the password form and the passwordless email form."
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop error, :any
end
