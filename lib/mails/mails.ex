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
      logo_url: logo_url(),
      paste_hint: l("Or paste this link into your browser:")
    }
  end

  # Email clients refuse to fetch images on non-standard ports as an
  # anti-SSRF measure, so we drop the logo when the resolved URL isn't
  # publicly fetchable (e.g. localhost:4000 in dev).
  defp logo_url do
    with raw when is_binary(raw) and raw != "" <-
           Config.get([:ui, :auth, :logo], nil) ||
             Config.get([:ui, :theme, :instance_icon], nil),
         absolute = Bonfire.Common.URIs.based_url(raw),
         true <- public_url?(absolute) do
      absolute
    else
      _ -> nil
    end
  end

  defp public_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: h, scheme: "http", port: 80} when is_binary(h) and h != "" -> true
      %URI{host: h, scheme: "https", port: 443} when is_binary(h) and h != "" -> true
      _ -> false
    end
  end

  defp public_url?(_), do: false

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
      :forgot_password -> forgot_password(account)
      :login -> login_link(account)
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
      base_url = "#{Bonfire.Common.URIs.base_url()}/signup/email/confirm/#{confirm_token}"

      url =
        case opts[:redirect_uri] do
          nil -> base_url
          redirect_uri -> "#{base_url}?redirect_uri=#{URI.encode_www_form(redirect_uri)}"
        end

      if Config.env() != :test or System.get_env("PHX_SERVER") == "yes",
        do: warn("Email confirmation link: #{url}")

      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:confirm_email, [])

      new()
      |> subject(Keyword.get(conf, :subject, "#{app_name} - " <> l("Confirm your email")))
      |> render_body(
        :confirm_action,
        Map.merge(branding_assigns(), %{
          current_account: account,
          confirm_url: url,
          app_name: app_name,
          heading: l("Welcome to %{app_name}", app_name: app_name),
          intro: l("Confirm your email to finish setting up your account."),
          cta: l("Confirm email"),
          disclaimer: l("If you didn't sign up, you can safely ignore this email.")
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
  def forgot_password(%Account{} = account) do
    confirm_token_email(account,
      conf_key: :forgot_password_email,
      log_label: "Reset link",
      default_subject: l("Reset your password"),
      heading: l("Reset your password"),
      intro: l("Click the button below to choose a new password."),
      cta: l("Reset password"),
      disclaimer: l("If you didn't request a password reset, you can safely ignore this email.")
    )
  end

  @doc """
  Sends a passwordless magic-link sign-in email.

  Used when an account is provisioned or requests a login via a flow that
  doesn't involve setting a password (e.g. gated mode). Shares the same
  confirm-token plumbing as `forgot_password/1` but with its own subject
  and template that frames the link as a sign-in, not a reset.
  """
  def login_link(%Account{} = account) do
    app_name = Bonfire.Mailer.app_name()

    confirm_token_email(account,
      conf_key: :login_link_email,
      log_label: "Login link",
      default_subject: l("Sign in"),
      heading: l("Sign in to %{app_name}", app_name: app_name),
      intro:
        l(
          "Click the button below to sign in. No password needed — the link will log you in directly."
        ),
      cta: l("Sign in"),
      disclaimer: l("If you didn't request this, you can safely ignore this email.")
    )
  end

  defp confirm_token_email(%Account{} = account, opts) do
    confirm_token = e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(opts[:conf_key], [])

      app_name = Bonfire.Mailer.app_name()
      url = url_path(Bonfire.UI.Me.ForgotPasswordController) <> "/" <> confirm_token

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
          disclaimer: opts[:disclaimer]
        })
      )
      |> mjmlify_html()
    else
      error(l("No confirmation token"))
    end
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
