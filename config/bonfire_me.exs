import Config

config :bonfire_me,
  templates_path: "lib",
  localisation_path: "priv/localisation"

alias Bonfire.Me.Accounts

config :bonfire_me, Accounts.Emails,
  confirm_email: [subject: "Confirm your email - Bonfire"],
  forgot_password: [subject: "Reset your password - Bonfire"]
