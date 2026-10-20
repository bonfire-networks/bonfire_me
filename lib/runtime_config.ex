defmodule Bonfire.Me.RuntimeConfig do
  @behaviour Bonfire.Common.ConfigModule
  require Logger
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

    # how long an emailed link keeps working after it was first used. Registered under the app that owns the Email schema, since that is where `Email` reads its config from. Only set when the env var is, so the default of five minutes applies otherwise.
    if grace = email_link_grace_seconds() do
      config :bonfire_data_identity, Bonfire.Data.Identity.Email, confirm_grace: {grace, :second}
    end

    #### Pointer class configuration

    config :bonfire_me, Bonfire.Me.Accounts,
      epics: [
        delete: []
      ]

    # config :bonfire_me, Bonfire.Me.Users,
    # whether profiles should be dicoverable by search engines (can be overriden in user settings)
    # undiscoverable: false,
  end

  @doc """
  Seconds an emailed link (signup confirmation, sign-in or password reset) keeps working after it was first used, from the `EMAIL_LINK_GRACE_SECONDS` env var. A whole number from 0 up, where 0 makes links strictly single-use. Returns `nil` when the variable is unset or empty, so the default applies. An invalid value also returns `nil`, with a warning.
  """
  def email_link_grace_seconds(value \\ System.get_env("EMAIL_LINK_GRACE_SECONDS"))

  def email_link_grace_seconds(value) when value in [nil, ""], do: nil

  def email_link_grace_seconds(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {seconds, ""} when seconds >= 0 ->
        seconds

      _ ->
        Logger.warning(
          "Ignoring EMAIL_LINK_GRACE_SECONDS=#{inspect(value)}: expected a whole number of seconds, 0 or more. Using the default."
        )

        nil
    end
  end
end
