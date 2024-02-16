import Config

config :bonfire,
  localisation_path: "priv/localisation"

config :bonfire, :ui, invites_component: Bonfire.Invite.Links.Web.InvitesLive
