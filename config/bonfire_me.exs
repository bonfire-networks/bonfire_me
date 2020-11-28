use Mix.Config

config :bonfire_me, :web_module, Bonfire.Web
config :bonfire_me, :repo_module, Bonfire.Repo
config :bonfire_me, :mailer_module, Bonfire.Mailer
config :bonfire_me, :templates_path, "lib"

alias Bonfire.Me.Accounts

config :bonfire_me, Accounts.Emails,
  confirm_email: [subject: "Confirm your email - Bonfire"],
  reset_password: [subject: "Reset your password - Bonfire"]
