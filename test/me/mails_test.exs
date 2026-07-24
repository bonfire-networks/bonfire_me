defmodule Bonfire.Me.MailsTest do
  use ExUnit.Case, async: true
  use Bonfire.Common.Config

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.Mails

  @account %Account{email: %{confirm_token: "tok-#{System.unique_integer([:positive])}"}}

  setup do
    # Most tests exercise the extension defaults independently of the active flavour.
    # Individual override tests replace this process-local value explicitly.
    Process.put([:bonfire, Bonfire.Me.Mails], [])
    :ok
  end

  for fun <- [:login_link, :forgot_password, :signup_confirm_email] do
    test "#{fun}/1 renders both bodies and a subject" do
      email = apply(Mails, unquote(fun), [@account])

      assert is_binary(email.subject) and email.subject != ""
      assert email.html_body =~ "<!doctype html"
      assert email.html_body =~ "tok-"
      assert email.text_body =~ "tok-"
    end

    test "#{fun}/1 inlines the configured email_theme palette" do
      email = apply(Mails, unquote(fun), [@account])
      theme = Config.get([:ui, :auth, :email_theme], [])
      primary = theme[:primary] || "#e63946"
      body_bg = theme[:body_bg] || "#fff7f7"

      assert email.html_body =~ primary
      assert email.html_body =~ body_bg
    end
  end

  describe "go destination in links" do
    @go "/write/article-123"
    @encoded_go URI.encode_www_form(@go)

    test "login_link/2 embeds the go destination in the confirm URL" do
      email = Mails.login_link(@account, go: @go)

      assert email.text_body =~ "go=" <> @encoded_go
      assert email.html_body =~ "go=" <> @encoded_go
    end

    test "signup_confirm_email/2 embeds the go destination in the confirm URL" do
      email = Mails.signup_confirm_email(@account, go: @go)

      assert email.text_body =~ "go=" <> @encoded_go
      assert email.html_body =~ "go=" <> @encoded_go
    end

    test "login_link/1 without go has no go param" do
      email = Mails.login_link(@account)
      refute email.text_body =~ "go="
    end
  end

  describe "registration_hint/1" do
    @signup_url "https://example.com/signup"

    test "renders both bodies and a subject" do
      email = Mails.registration_hint(@signup_url)

      assert is_binary(email.subject) and email.subject != ""
      assert email.html_body =~ "<!doctype html"
      assert email.html_body =~ @signup_url
      assert email.text_body =~ @signup_url
    end

    test "renders its safety disclaimer without requiring a sign-off" do
      email = Mails.registration_hint(@signup_url)

      assert email.text_body =~ "If you didn't request this"
      assert email.html_body =~ "If you didn't request this"
    end
  end

  describe "forgot_password/1" do
    test "renders its safety disclaimer without requiring a sign-off" do
      email = Mails.forgot_password(@account)

      assert email.text_body =~ "If you didn't request a password reset"
      assert email.html_body =~ "If you didn't request a password reset"
    end
  end

  describe "login_link/1" do
    test "renders the complete localized magic-link message" do
      email = Mails.login_link(@account)

      assert email.subject =~ "Your login link for"
      assert email.text_body =~ "Hello,"
      assert email.text_body =~ "Click the following link to sign in to"
      assert email.text_body =~ "this link expires after 24 hours"
      assert email.text_body =~ "See you soon!"
      assert email.text_body =~ "You can also copy this URL and paste it into your browser:"
    end

    test "uses the configured instance name" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "Jacobin.social")

      email = Mails.login_link(@account)

      assert email.subject == "Jacobin.social - Your login link for Jacobin.social"
      assert email.text_body =~ "sign in to Jacobin.social"
      assert email.text_body =~ "Your Jacobin.social team"
    end

    test "renders text branding without configured images" do
      Process.put([:bonfire, :ui, :auth, :project_branding_image], "/images/project-brand.png")
      Process.put([:bonfire, :ui, :auth, :logo], "/images/footer-logo.png")
      Process.put([:bonfire, :ui, :theme, :instance_name], "Jacobin.social")

      email = Mails.login_link(@account)

      assert email.html_body =~ "Jacobin.social"
      refute email.html_body =~ "/images/project-brand.png"
      refute email.html_body =~ "/images/footer-logo.png"
      refute email.html_body =~ "<img"
      assert email.attachments == []
    end

    test "per-instance config overrides the copy" do
      Process.put([:bonfire, Bonfire.Me.Mails],
        login_link_email: [
          subject: "Dein Login-Link für Jacobin.social",
          signature: "Deine Jacobin-Redaktion"
        ]
      )

      email = Mails.login_link(@account)

      assert email.subject == "Dein Login-Link für Jacobin.social"
      assert email.text_body =~ "Deine Jacobin-Redaktion"
      refute email.text_body =~ "team"
      # unset keys still fall back to the extension's own copy
      assert email.text_body =~ "See you soon!"
    end

    test "places the copyable URL before the expiry and sign-off" do
      email = Mails.login_link(@account)

      {url_position, _} = :binary.match(email.text_body, "You can also copy this URL")
      {expiry_position, _} = :binary.match(email.text_body, "this link expires after 24 hours")
      {signoff_position, _} = :binary.match(email.text_body, "See you soon!")

      assert url_position < expiry_position
      assert expiry_position < signoff_position
    end
  end

  describe "signup_confirm_email/1" do
    test "renders the generic signup message in the shared layout" do
      email = Mails.signup_confirm_email(@account)

      assert email.subject =~ "Confirm your email"
      assert email.text_body =~ "Hello,"
      assert email.text_body =~ "thanks for signing up to"
      assert email.text_body =~ "confirm your email and get started"
      assert email.text_body =~ "Confirm email"
      assert email.text_body =~ "See you soon!"
      assert email.text_body =~ "You can also copy this URL and paste it into your browser:"
    end

    test "greets the user by first name when known" do
      account = %Account{
        @account
        | accounted: [%{user: %{profile: %{name: "Rosa Luxemburg"}}}]
      }

      email = Mails.signup_confirm_email(account)

      assert email.text_body =~ "Hello Rosa,"
      refute email.text_body =~ "Hello,"
    end

    test "uses the configured instance name" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "Jacobin.social")

      email = Mails.signup_confirm_email(@account)

      assert email.subject == "Jacobin.social - Confirm your email"
      assert email.text_body =~ "thanks for signing up to Jacobin.social"
      assert email.text_body =~ "Your Jacobin.social team"
    end

    test "per-instance config overrides the copy" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "Jacobin.social")

      Process.put([:bonfire, Bonfire.Me.Mails],
        confirm_email: [
          subject: "Dein Abo ist hiermit bestätigt",
          intro: "danke für dein Abonnement bei Jacobin.",
          cta: "Zugang erhalten",
          signoff: "Bis bald!"
        ]
      )

      email = Mails.signup_confirm_email(@account)

      # an override replaces the whole subject, app_name prefix included
      assert email.subject == "Dein Abo ist hiermit bestätigt"
      assert email.text_body =~ "danke für dein Abonnement bei Jacobin."
      assert email.text_body =~ "Zugang erhalten"
      assert email.text_body =~ "Bis bald!"
      # unset keys still fall back to the extension's own copy
      assert email.text_body =~ "confirm your email and get started"
      refute email.text_body =~ "thanks for signing up"
    end

    test "overrides are used as written, without %{} interpolation" do
      Process.put([:bonfire, :ui, :theme, :instance_name], "Jacobin.social")
      Process.put([:bonfire, Bonfire.Me.Mails], confirm_email: [cta: "Zugang erhalten"])

      email = Mails.signup_confirm_email(@account)

      # the untouched default still interpolates
      assert email.text_body =~ "thanks for signing up to Jacobin.social"
      refute email.text_body =~ "%{"
    end
  end
end
