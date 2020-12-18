defmodule Bonfire.Me.Identity.Accounts.LoginFields do

  use Ecto.Schema
  alias Ecto.Changeset
  alias Bonfire.Me.Identity.Accounts.LoginFields

  embedded_schema do
    field :form
    field :email_or_username, :string
    field :password, :string
    field :remember_me, :boolean
    field :email, :string
    field :username, :string
  end

  @cast [:email_or_username, :password]
  @required @cast

  def changeset(form \\ %LoginFields{}, attrs) do
    form
    |> Changeset.cast(attrs, @cast)
    |> Changeset.validate_required(@required)
    |> validate_username_or_email
  end

  defp validate_username_or_email(changeset) do
    case Changeset.fetch_change(changeset, :email_or_username) do
      {:ok, eou} ->
        cond do
          Regex.match?(~r(^@?[a-z][a-z0-9]+$)i, eou) ->
            Changeset.put_change(changeset, :username, eou)
          Regex.match?(~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$), eou) ->
            Changeset.put_change(changeset, :email, eou)
          true ->
            Changeset.put_error(changeset, :email_or_username, "You must provide a valid email address or @username.")
        end
      _ -> changeset
    end
  end

end
