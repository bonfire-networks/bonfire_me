defmodule Bonfire.Me.Mails do
  @moduledoc """
  Handles email sending functionality for accounts and users
  """

  use Bamboo.Template, view: Bonfire.Me.Mails.EmailView

  # import Bonfire.Me.Integration
  use Bonfire.Common.E
  import Bonfire.Common.URIs
  import Untangle
  use Gettext, backend: Bonfire.Common.Localise.Gettext
  import Bonfire.Common.Localise.Gettext.Helpers

  use Bonfire.Common.Config
  alias Bonfire.Data.Identity.Account
  # alias Bonfire.Me.Mails.EmailView
  alias Bonfire.Common.Utils

  def mailer, do: Config.get(:mailer_module)

  @doc """
  Sends a confirmation email based on the specified action.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.
    - `opts`: Options including `:confirm_action`, which determines the type of email to send.

  ## Examples

      iex> Bonfire.Me.Mails.confirm_email(%Account{})
      # sends signup confirmation

      iex> Bonfire.Me.Mails.confirm_email(%Account{}, confirm_action: :forgot_password)

      iex> Bonfire.Me.Mails.confirm_email(%Account{}, confirm_action: :forgot_password)
  """
  def confirm_email(account, opts \\ []) do
    case opts[:confirm_action] do
      :forgot_password -> forgot_password(account)
      :login -> forgot_password(account)
      _ -> signup_confirm_email(account, opts)
    end
  end

  @doc """
  Sends a confirmation email for user signup.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.
    - `opts`: Options including `:redirect_uri` for deep-linking back to mobile apps after confirmation.

  ## Examples

      iex> Bonfire.Me.Mails.signup_confirm_email(%Account{email: %{confirm_token: "token"}})
      iex> Bonfire.Me.Mails.signup_confirm_email(%Account{email: %{confirm_token: "token"}}, redirect_uri: "myapp://callback")
  """
  def signup_confirm_email(%Account{} = account, opts \\ []) do
    confirm_token = e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      app_name = Utils.maybe_apply(Bonfire.Application, :name, [])
      # Construct URL directly since url_path helper doesn't work well with resources routes
      base_url = "#{Bonfire.Common.URIs.base_url()}/signup/email/confirm/#{confirm_token}"

      # Add redirect_uri as query param if provided (for mobile app deep-linking)
      url =
        case opts[:redirect_uri] do
          nil -> base_url
          redirect_uri -> "#{base_url}?redirect_uri=#{URI.encode_www_form(redirect_uri)}"
        end

      if Config.env() != :test or
           System.get_env("PHX_SERVER") == "yes",
         do: warn("Email confirmation link: #{url}")

      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:confirm_email, [])

      mailer().new()
      |> assign(:current_account, account)
      |> assign(:confirm_url, url)
      |> assign(:app_name, app_name)
      |> mailer().subject(
        Keyword.get(conf, :subject, "#{app_name} - " <> l("Confirm your email"))
      )
      |> render(:confirm_email)

      # |> put_html_layout({EmailView, "confirm_email.html"})
      # |> put_text_layout({EmailView, "confirm_email.text"})
      # |> debug("signup_confirm_email mail")
    else
      error("No confirmation token")
    end
  end

  @doc """
  Sends a password reset email.

  ## Parameters

    - `account`: The `%Account{}` struct for the user.

  ## Examples

      iex> Bonfire.Me.Mails.forgot_password(%Account{email: %{confirm_token: "token"}})
      :ok
  """
  def forgot_password(%Account{} = account) do
    confirm_token = e(account, :email, :confirm_token, nil)

    if is_binary(confirm_token) do
      conf =
        Config.get(__MODULE__, [])
        |> Keyword.get(:forgot_password_email, [])

      app_name = Utils.maybe_apply(Bonfire.Application, :name, [])
      url = url_path(Bonfire.UI.Me.ForgotPasswordController, confirm_token)

      if Config.env() != :test or
           System.get_env("PHX_SERVER") == "yes",
         do: warn("Reset link: #{url}")

      mailer().new()
      |> assign(:current_account, account)
      |> assign(:confirm_url, url)
      |> assign(:app_name, app_name)
      |> mailer().subject(
        Keyword.get(conf, :subject, "#{app_name} - #{l("Reset your password")}")
      )
      |> render(:forgot_password)
    else
      error(l("No confirmation token"))
    end
  end
end
