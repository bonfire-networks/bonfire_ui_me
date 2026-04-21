import Config

config :bonfire_common,
  localisation_path: "priv/localisation"

# Extensions add themselves to this list in their own config (see
# `Bonfire.UI.Me.LoginEmailProvider` behaviour). Iterated by
# `Bonfire.UI.Me.LoginEmailProviders.ensure/1` on unknown login emails.
config :bonfire_ui_me,
  login_email_providers: []
