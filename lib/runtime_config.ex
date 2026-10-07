defmodule Bonfire.Me.RuntimeConfig do
  @behaviour Bonfire.Common.ConfigModule
  def config_module, do: true

  @yes? ~w(true yes 1)

  def config do
    import Config

    # letters from any script in local usernames (e.g. josé or 你好), not only a-z, 0-9 and _. Off by default since some other fediverse software can't find or mention such users yet (W3C SocialCG ActivityPub and WebFinger report, 3.1.2).
    config :bonfire_me, Bonfire.Me.Characters,
      unicode_usernames: System.get_env("UNICODE_USERNAMES") in @yes?

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
