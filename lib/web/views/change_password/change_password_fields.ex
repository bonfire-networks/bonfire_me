defmodule Bonfire.Me.Accounts.ChangePasswordFields do

  use Ecto.Schema
  alias Ecto.Changeset
  alias Bonfire.Me.Accounts.ChangePasswordFields

  embedded_schema do
    field :old_password, :string
    field :password, :string
    field :password_confirmation, :string
  end

  @cast [:old_password, :password, :password_confirmation]

  def changeset(form \\ %ChangePasswordFields{}, attrs, resetting_password? \\ false)

  def changeset(form, attrs, true) do
    form
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required([:password, :password_confirmation])
    |> validate
  end

  def changeset(form, attrs, _) do
    form
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required([:old_password, :password, :password_confirmation])
    |> validate
  end

  defp validate(cs) do
    cs
    |> Changeset.validate_length(:password, min: 10, max: 64)
    |> Changeset.validate_confirmation(:password)
  end

end
