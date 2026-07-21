defmodule Bonfire.Me.Mails do
  @moduledoc """
  Transactional emails: signup confirm, password reset, magic-link sign-in.
  Uses `Phoenix.Swoosh` with a shared MJML template.
  """

  use Phoenix.Swoosh,
    view: Bonfire.Me.Mails.EmailView,
    layout: {Bonfire.Me.Mails.EmailView, :email},
    formats: %{"mjml" => :html_body, "text" => :text_body}

  use Bonfire.Common.E
  import Bonfire.Common.URIs
  import Untangle
  use Gettext, backend: Bonfire.Common.Localise.Gettext
  import Bonfire.Common.Localise.Gettext.Helpers

  use Bonfire.Common.Config
  alias Bonfire.Data.Identity.Account

  # Runtime backstop in case `[:ui, :auth, :email_theme]` config is partial
  # or unset. Instance-level Settings overrides are mirrored into OTP env
  # at boot, so `Config.get/2` already sees them.
  @default_email_theme [
    primary: "#e63946",
    primary_content: "#ffffff",
    body_bg: "#fff7f7",
    body_text: "#1f1f1f",
    muted: "#6b6b6b"
  ]

  def mailer, do: Config.get(:mailer_module)

  defp branding_assigns do
    theme = Keyword.merge(@default_email_theme, Config.get([:ui, :auth, :email_theme], []))

    %{
      theme: Map.new(theme),
      paste_hint: l("Or paste this link into your browser:")
    }
  end

  @doc """
  Sends a confirmation email based on the specified action.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.
    - `opts`: Options including `:confirm_action`, which determines the type of email to send.

  ## Examples

      iex> Bonfire.Me.Mails.confirm_email(%Account{})
      # sends signup confirmation

      iex> Bonfire.Me.Mails.confirm_email(%Account{}, confirm_action: :forgot_password)
  """
  def confirm_email(account, opts \\ []) do
    case opts[:confirm_action] do
      :forgot_password -> forgot_password(account, opts)
      :login -> login_link(account, opts)
      _ -> signup_confirm_email(account, opts)
    end
  end

  @doc """
  Sends a confirmation email for user signup.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.
    - `opts`: Options including `:redirect_uri` for deep-linking back to mobile apps after confirmation.
  """
  def signup_confirm_email(%Account{} = account, opts \\ []) do
    confirm_token = e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      app_name = Bonfire.Mailer.app_name()
      first_name = first_name(account)
      base_url = "#{Bonfire.Common.URIs.base_url()}/signup/email/confirm/#{confirm_token}"

      url =
        append_query(base_url, go: opts[:go], redirect_uri: opts[:redirect_uri])

      if Config.env() != :test or System.get_env("PHX_SERVER") == "yes",
        do: warn("Email confirmation link: #{url}")

      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:confirm_email, [])

      new()
      |> subject(
        Keyword.get(conf, :subject, "#{app_name} - " <> l("Your subscription is confirmed"))
      )
      |> render_body(
        :confirm_action,
        Map.merge(branding_assigns(), %{
          current_account: account,
          confirm_url: url,
          app_name: app_name,
          heading: greeting(first_name),
          intro:
            l(
              "thanks for subscribing to %{app_name}. You're supporting independent, critical journalism.",
              app_name: app_name
            ),
          intro_2:
            l(
              "Our system is passwordless. Just click the following link to get access to %{app_name}:",
              app_name: app_name
            ),
          cta: l("Get access"),
          disclaimer: l("If you didn't sign up, you can safely ignore this email."),
          signoff: l("See you soon!"),
          signature: signature(app_name),
          paste_hint: l("You can also copy this URL and paste it into your browser:")
        })
      )
      |> mjmlify_html()
    else
      error("No confirmation token")
    end
  end

  @doc """
  Sends a password reset email.
  """
  def forgot_password(%Account{} = account, opts \\ []) do
    confirm_token_email(account,
      conf_key: :forgot_password_email,
      log_label: "Reset link",
      default_subject: l("Reset your password"),
      heading: l("Reset your password"),
      intro: l("Click the button below to choose a new password."),
      cta: l("Reset password"),
      disclaimer: l("If you didn't request a password reset, you can safely ignore this email."),
      go: opts[:go]
    )
  end

  @doc """
  Sends a passwordless magic-link sign-in email.

  Used when an account is provisioned or requests a login via a flow that
  doesn't involve setting a password (e.g. gated mode). Shares the same
  confirm-token plumbing as `forgot_password/1` but with its own subject
  and template that frames the link as a sign-in, not a reset.
  """
  def login_link(%Account{} = account, opts \\ []) do
    app_name = Bonfire.Mailer.app_name()
    first_name = first_name(account)

    confirm_token_email(account,
      conf_key: :login_link_email,
      log_label: "Login link",
      default_subject: l("Your login link for %{app_name}", app_name: app_name),
      heading: greeting(first_name),
      intro:
        l(
          "Click the following link to sign in to %{app_name}:",
          app_name: app_name
        ),
      cta: l("Sign in"),
      disclaimer:
        l(
          "For security reasons, this link expires after 24 hours. If you didn't request this login, you can simply ignore this email."
        ),
      signoff: l("See you soon!"),
      signature: signature(app_name),
      paste_hint: l("You can also copy this URL and paste it into your browser:"),
      go: opts[:go]
    )
  end

  # Greeting line, personalised when we know the recipient's first name.
  defp greeting(first_name) when is_binary(first_name),
    do: l("Hello %{first_name},", first_name: first_name)

  defp greeting(_), do: l("Hello,")

  # Sign-off name under the greeting. Instances that don't call themselves a
  # "team" (e.g. an editorial desk) can override this verbatim in config, in
  # which case it is used as-is rather than translated.
  defp signature(app_name) do
    case Config.get([:ui, :auth, :email_signature]) do
      custom when is_binary(custom) and custom != "" -> custom
      _ -> l("Your %{app_name} team", app_name: app_name)
    end
  end

  defp first_name(account) do
    account
    |> e(:accounted, [])
    |> List.wrap()
    |> Enum.find_value(&e(&1, :user, :profile, :name, nil))
    |> case do
      name when is_binary(name) -> name |> String.trim() |> String.split() |> List.first()
      _ -> nil
    end
  end

  defp confirm_token_email(%Account{} = account, opts) do
    confirm_token = e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(opts[:conf_key], [])

      app_name = Bonfire.Mailer.app_name()

      url =
        (url_path(Bonfire.UI.Me.ForgotPasswordController) <> "/" <> confirm_token)
        |> append_query(go: opts[:go])

      if Config.env() != :test or System.get_env("PHX_SERVER") == "yes",
        do: warn("#{opts[:log_label]}: #{url}")

      new()
      |> subject(Keyword.get(conf, :subject, "#{app_name} - #{opts[:default_subject]}"))
      |> render_body(
        :confirm_action,
        Map.merge(branding_assigns(), %{
          current_account: account,
          confirm_url: url,
          app_name: app_name,
          heading: opts[:heading],
          intro: opts[:intro],
          cta: opts[:cta],
          disclaimer: opts[:disclaimer],
          signoff: opts[:signoff],
          signature: opts[:signature],
          paste_hint: opts[:paste_hint] || l("Or paste this link into your browser:")
        })
      )
      |> mjmlify_html()
    else
      error(l("No confirmation token"))
    end
  end

  @doc """
  Builds a "how to get access" email for an unrecognised address in gated-login mode.

  Reuses the standard CTA-button template; `confirm_url` points to the instance's
  `external_signup_url` rather than a confirm token.
  """
  def registration_hint(signup_url) when is_binary(signup_url) and signup_url != "" do
    app_name = Bonfire.Mailer.app_name()

    new()
    |> subject("#{app_name} - #{l("How to get access")}")
    |> render_body(
      :confirm_action,
      Map.merge(branding_assigns(), %{
        app_name: app_name,
        heading: l("Get access to %{app_name}", app_name: app_name),
        intro: l("To get access, sign up via the link below."),
        cta: l("Sign up"),
        confirm_url: signup_url,
        paste_hint: l("Or paste this link into your browser:"),
        disclaimer: l("If you didn't request this, you can safely ignore this email.")
      })
    )
    |> mjmlify_html()
  end

  # Append the given params as a query string, keeping only present binary values
  # and URL-encoding them. `go` (the intended post-auth destination) and
  # `redirect_uri` (mobile deep-link) ride along in the confirm/login link.
  defp append_query(url, params) do
    query =
      params
      |> Enum.filter(fn {_k, v} -> is_binary(v) and v != "" end)
      |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode_www_form(v)}" end)

    if query == "", do: url, else: url <> "?" <> query
  end

  defp mjmlify_html(%{html_body: mjml} = email) when is_binary(mjml) do
    case Mjml.to_html(mjml) do
      {:ok, html} ->
        Map.put(email, :html_body, html)

      {:error, reason} ->
        error(reason, "MJML conversion failed; keeping raw MJML in html_body")
        email
    end
  end

  defp mjmlify_html(email), do: email
end
