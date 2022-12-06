defmodule Bonfire.Me.Accounts.ChangeEmailFields do
  use Ecto.Schema
  alias Ecto.Changeset
  alias Bonfire.Me.Accounts.ChangeEmailFields

  embedded_schema do
    field(:old_email, :string)
    field(:email, :string)
  end

  @cast [:old_email, :email]

  def changeset(
        form \\ %ChangeEmailFields{},
        attrs
      )

  def changeset(form, attrs) do
    form
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required([
      :old_email,
      :email
    ])
    |> validate()
  end

  defp validate(cs) do
    cs
    |> Changeset.validate_format(:email, ~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$))
    |> Changeset.validate_confirmation(:email)
  end
end
