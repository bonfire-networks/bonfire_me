defmodule Bonfire.Me.RuntimeConfig do
  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  def config do
    import Config

    config :bonfire_me, Bonfire.Me.Identity.Mails,
      confirm_email: [subject: "Confirm your email - Bonfire"],
      forgot_password: [subject: "Reset your password - Bonfire"]

    #### Pointer class configuration

    config :bonfire_me, Bonfire.Me.Accounts,
      epics: [
        delete: []
      ]

    # config :bonfire_me, Bonfire.Me.Users,
    # whether profiles should be dicoverable by search engines (can be overriden in user settings)
    # undiscoverable: false,
  end
end
