defmodule Bonfire.Me.Accounts.ConfirmEmailFields do
  @moduledoc "A changeset for confirming an email address"
  use Ecto.Schema
  alias Ecto.Changeset
  alias Bonfire.Me.Accounts.ConfirmEmailFields

  embedded_schema do
    field(:email, :string)
  end

  @cast [:email]
  @required @cast

  def changeset(form \\ %ConfirmEmailFields{}, attrs) do
    form
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> Changeset.validate_format(:email, ~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$))
  end
end
