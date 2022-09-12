import Config

config :bonfire_ui_me,
  localisation_path: "priv/localisation"

config :bonfire, :ui, invites_component: Bonfire.Invite.Links.Web.InvitesLive
