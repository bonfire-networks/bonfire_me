defmodule Bonfire.Me.Accounts.ResetPasswordFields do

  use Ecto.Schema
  alias Ecto.Changeset
  alias Bonfire.Me.Accounts.ResetPasswordFields

  embedded_schema do
    field :reset_token, :string
    field :password, :string
    field :password_confirmation, :string
  end

  @cast [:reset_token, :password, :password_confirmation]
  @required @cast

  def changeset(form \\ %ResetPasswordFields{}, attrs) do
    form
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.validate_length(:password, min: 10, max: 64)
    |> Changeset.validate_confirmation(:password)
  end

end
