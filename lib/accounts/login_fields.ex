defmodule Bonfire.Me.Accounts.LoginFields do
  use Ecto.Schema
  alias Ecto.Changeset
  alias Bonfire.Me.Accounts.LoginFields

  embedded_schema do
    # inputs
    field(:email_or_username, :string)
    field(:password, :string)
    field(:remember_me, :boolean)
    # where the user was before
    field(:go, :string)
    # outputs
    field(:email, :string)
    field(:username, :string)
    embeds_one(:auth_second_factor, Bonfire.Data.Identity.AuthSecondFactor)
  end

  @required [:email_or_username, :password]
  @optional [:remember_me, :go]
  @cast @required ++ @optional

  def changeset(form \\ %LoginFields{}, attrs) do
    form
    |> Changeset.cast(attrs, @cast)
    # |> Changeset.cast_embed(:auth_second_factor)
    |> Changeset.validate_required(@required)
    |> validate_username_or_email()
  end

  defp validate_username_or_email(changeset) do
    case Changeset.fetch_change(changeset, :email_or_username) do
      {:ok, eou} ->
        cond do
          Regex.match?(~r(^@?[a-z][a-z0-9_]+$)i, eou) ->
            Changeset.put_change(changeset, :username, eou)

          Regex.match?(~r(^[^@]{1,128}@[^@]{2,128}$), eou) ->
            Changeset.put_change(changeset, :email, eou)

          true ->
            Changeset.add_error(
              changeset,
              :email_or_username,
              "You need to provide a valid email address or @username."
            )
        end

      _ ->
        changeset
    end
  end
end
