defmodule Bonfire.Me.Accounts.SecondFactors do
  @moduledoc "Support for second-factor authentication. Powered by `NimbleTOTP`."

  use Arrows
  use Bonfire.Common.Utils
  import Bonfire.Me.Integration
  import Untangle

  alias Bonfire.Data.Identity.AuthSecondFactor
  # alias Bonfire.Data.Identity.Account
  alias Ecto.Changeset

  @doc """
  Checks if second-factor authentication (TOTP) is enabled on the instance.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.enabled?()
      true
  """
  def enabled? do
    module_enabled?(Bonfire.Data.Identity.AuthSecondFactor) and
      module_enabled?(NimbleTOTP)
  end

  @doc """
  Generates a new TOTP secret if second-factor authentication is enabled.

   The secret is a random 20 bytes binary that is used to generate the QR Code to enable 2FA using auth applications. 

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.new()
      "JBSWY3DPEHPK3PXP"
  """
  def new() do
    if enabled?(), do: NimbleTOTP.secret()
  end

  @doc """
  Generates a new TOTP URI for use in an authentication app.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.new_uri()
      "otpauth://totp/bonfire:AccountName?secret=APYWY3DPEHPK3PXV&issuer=Issuer"

      iex> Bonfire.Me.Accounts.SecondFactors.new_uri("JBSWY3DPEHPK3PXP")
      "otpauth://totp/bonfire:AccountName?secret=JBSWY3DPEHPK3PXP&issuer=Issuer"
  """
  def new_uri(secret \\ nil) do
    if enabled?() do
      issuer =
        Config.get(
          [:ui, :theme, :instance_name],
          Bonfire.Common.Utils.maybe_apply(
            Bonfire.Application,
            :name,
            []
          )
        )

      NimbleTOTP.otpauth_uri("#{issuer}", secret || new(), issuer: "#{issuer}")
    end
  end

  @doc """
  Generates a QR code for the TOTP URI.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.new_qrcode()
      "<svg>...</svg>"
  """
  def new_qrcode(opts \\ []) do
    if enabled?(),
      do:
        (opts[:uri] || new_uri(opts[:secret]))
        |> EQRCode.encode()
        |> EQRCode.svg(width: 264)
  end

  @doc """
  Formats a TOTP secret into a human-readable format.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.format_secret("JBSWY3DPEHPK3PXP")
      "JBSW Y3DP EHPK 3PXP"
  """
  def format_secret(secret \\ new()) do
    secret
    |> Base.encode32(padding: false)
    |> String.graphemes()
    # |> Enum.map(&maybe_highlight_digit/1)
    |> Enum.chunk_every(4)
    |> Enum.intersperse(" ")
  end

  @doc """
  Retrieves the second factor record for an account, if any.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.get_account_totp(%{auth_second_factor: %AuthSecondFactor{}})
      %AuthSecondFactor{}

      iex> Bonfire.Me.Accounts.SecondFactors.get_account_totp("some_id")
      %AuthSecondFactor{}
  """
  def get_account_totp(%{auth_second_factor: %AuthSecondFactor{} = totp}) do
    totp
  end

  def get_account_totp(account) do
    case uid(account) do
      id when is_binary(id) ->
        repo().get_by(AuthSecondFactor, id: id)

      _ ->
        nil
    end
  end

  @doc """
  Conditionally casts a TOTP changeset based on parameters and options.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.maybe_cast_totp_changeset(changeset, %{auth_second_factor: %{code: "123456"}}, [])
      %Ecto.Changeset{data: %AuthSecondFactor{}}
  """
  def maybe_cast_totp_changeset(changeset, params, opts) do
    if Bonfire.Me.Accounts.SecondFactors.enabled?() do
      debug("enabled")
      code = e(params, :auth_second_factor, :code, nil)

      if not is_nil(code) and code != "" do
        debug(code, "code")

        Changeset.cast_assoc(
          changeset,
          :auth_second_factor,
          required: false,
          with: &changeset(&1, &2, opts)
        )
      else
        # case opts[:auth_second_factor_secret] do
        #   secret when is_binary(secret) ->
        #     debug("generate")
        #     changeset
        #     |> Changeset.put_assoc(
        #       :auth_second_factor,
        #       new_struct(secret)
        #     )
        #     # |> debug
        #   _ ->
        debug("no secret or code provided")
        changeset

        # end
      end
    else
      changeset
    end
  end

  @doc """
   Creates or updates a TOTP changeset.

    The secret will only be updated if the OTP code sent is valid.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.changeset(%AuthSecondFactor{}, %{secret: "new_secret"}, [])
      %Ecto.Changeset{data: %AuthSecondFactor{}}
  """
  def changeset(
        %AuthSecondFactor{} = totp \\ %AuthSecondFactor{},
        attrs,
        opts \\ []
      ) do
    secret = totp.secret || opts[:auth_second_factor_secret] || e(attrs, :secret, nil)

    # |> debug("secret")
    totp
    |> Map.put(:secret, secret)
    |> debug()
    |> AuthSecondFactor.changeset(attrs)
    |> debug()

    # |> AuthSecondFactor.ensure_backup_codes() # TODO
    # let's make sure the secret propagates to the changeset.
    # |> Ecto.Changeset.force_change(:secret, secret)
  end

  def new_struct(secret \\ nil) do
    %AuthSecondFactor{}
    |> Map.put(:secret, secret || new())
    |> debug()
  end

  # TODO
  # @doc """
  # Regenerates the account backup codes for totp.
  # ## Examples
  #     iex> regenerate_account_totp_backup_codes(%AuthSecondFactor{})
  #     %AuthSecondFactor{backup_codes: [...]}
  # """
  # def regenerate_account_totp_backup_codes(totp) do
  #   {:ok, updated_totp} =
  #     Repo.transaction(fn ->
  #       totp
  #       |> Ecto.Changeset.change()
  #       |> AuthSecondFactor.regenerate_backup_codes()
  #       |> Repo.update!()
  #     end)

  #   updated_totp
  # end

  @doc """
  Disables the TOTP configuration for the given account.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.delete_account_totp(%AuthSecondFactor{id: "some_id"})

      iex> Bonfire.Me.Accounts.SecondFactors.delete_account_totp("some_id")
  """
  def delete_account_totp(%AuthSecondFactor{} = account_totp) do
    repo().transaction(fn ->
      repo().delete!(account_totp)
    end)

    :ok
  end

  def delete_account_totp(account) do
    get_account_totp(account)
    |> delete_account_totp()
  end

  @doc """
  Validates if the given TOTP code is valid.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.validate_account_totp(%AuthSecondFactor{id: "some_id", secret: "JBSWY3DPEHPK3PXP"}, "123456")
      :valid_totp

       iex> Bonfire.Me.Accounts.SecondFactors.validate_account_totp("some_id", "123456")
      :valid_totp
  """
  def validate_account_totp(%AuthSecondFactor{} = totp, code) do
    cond do
      AuthSecondFactor.valid_totp?(totp, code) ->
        :valid_totp

      # changeset = AuthSecondFactor.validate_backup_code(totp, code) ->
      #   {:ok, totp} =
      #     Repo.transaction(fn ->
      #       Repo.update!(changeset)
      #     end)
      #   {:valid_backup_code, Enum.count(totp.backup_codes, &is_nil(&1.used_at))}

      true ->
        :invalid
    end
  end

  def validate_account_totp(account, code) do
    case get_account_totp(account) do
      %AuthSecondFactor{} = totp ->
        validate_account_totp(totp, code)

      _ ->
        :no_totp
    end
  end

  @doc """
  Tries to authenticates an account using the provided parameters.

  ## Examples

      iex> Bonfire.Me.Accounts.SecondFactors.maybe_authenticate("account_id", %{"auth_second_factor" => %{"code" => "123456"}})
      {:ok, :valid_totp}
  """
  def maybe_authenticate(account, params) do
    # debug(params)

    if Bonfire.Me.Accounts.SecondFactors.enabled?() do
      case validate_account_totp(
             account,
             e(params, "auth_second_factor", "code", nil)
           ) do
        :valid_totp ->
          debug("valid_totp :-)")
          {:ok, :valid_totp}

        # {:valid_backup_code, remaining} ->
        #   plural = ngettext("backup code", "backup codes", remaining)

        #   {:ok,
        #     "You have #{remaining} #{plural} left. " <>
        #       "You can generate new ones under the Two-factor authentication section in the Settings page"
        #   )}

        :no_totp ->
          debug("no_totp for this account")
          {:ok, :no_totp}

        :invalid ->
          error("Invalid two-factor authentication code")
      end
    else
      {:ok, :disabled}
    end
  end
end
