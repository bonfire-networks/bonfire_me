defmodule Bonfire.Me.Fake do

  alias Bonfire.Data.Identity.Account
  alias Bonfire.Me.{Accounts, Users}

  # import Bonfire.Me.Integration

  def fake_account!(attrs \\ %{}) do
    {:ok, account} = Accounts.signup(signup_form(attrs), must_confirm: false)
    account
  end

  # def fake_account!(attrs \\ %{}) do
  #   cs = Accounts.signup_changeset(Fake.account(attrs))
  #   assert {:ok, account} = repo().insert(cs)
  #   account
  # end

  def fake_user!(account \\ %{}, attrs \\ %{})

  def fake_user!(%Account{}=account, attrs) do
    {:ok, user} = Users.create(create_user_form(attrs), account)
    user
  end
  # def fake_user!(%Account{}=account \\ %{}, attrs \\ %{}) do
  #   assert {:ok, user} = Users.create(Fake.user(attrs), account)
  #   user
  # end
  def fake_user!(account_attrs, user_attrs) do
    fake_user!(fake_account!(account_attrs), user_attrs)
  end


  def email, do: Faker.Internet.email()
  def confirm_token, do: Base.encode32(Faker.random_bytes(10), pad: false)
  # def location, do: Faker.Pokemon.location()
  def name, do: Faker.Person.name()
  def password, do: Base.encode32(Faker.random_bytes(10), pad: false)
  def summary, do: Faker.Lorem.sentence(6..15)
  def username, do: String.replace(Faker.Internet.user_name(), ~r/\./, "_")
  def atusername, do: "@" <> username()
  def website, do: Faker.Internet.domain_name()
  def location, do: Faker.Pokemon.location()
  def icon_url(slug \\ nil), do: Faker.Avatar.image_url(slug, 140,140)
  def image_url(slug \\ nil), do: Faker.Avatar.image_url(slug)
  def avatar_url(slug \\ nil), do: Faker.Avatar.image_url(slug, 140,140)
  # def avatar_url(id \\ "anon"), do: "https://thispersondoesnotexist.com/image" #?#{id}"

  def image(%{shared_user: %{label: _}}), do: Faker.Internet.image_url()
  def image(%{id: id, profile: _}), do: avatar_url(id)
  def image(%{id: id, name: _}), do: avatar_url(id)
  def image(%{id: id}), do: image_url(id)
  def image(_), do: image_url()

  defp put_form_lazy(base, key, fun) do
    Map.put_new_lazy base, key, fn ->
      fun.(Map.get(base, key, %{}))
    end
  end

  def character_subform(base \\ %{}) do
    base
    |> Map.put_new_lazy(:username, &username/0)
  end

  def credential_subform(base \\ %{}) do
    base
    |> Map.put_new_lazy(:password, &password/0)
  end

  def email_subform(base \\ %{}) do
    base
    |> Map.put_new_lazy(:email_address, &email/0)
  end

  def profile_subform(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name,    &name/0)
    |> Map.put_new_lazy(:summary, &summary/0)
  end

  def signup_form(base \\ %{}) do
    base
    |> put_form_lazy(:email,      &email_subform/1)
    |> put_form_lazy(:credential, &credential_subform/1)
  end

  def create_user_form(base \\ %{}) do
    base
    |> put_form_lazy(:character, &character_subform/1)
    |> put_form_lazy(:profile,   &profile_subform/1)
  end

  def user_live(base \\ %{}) do
    base
    # |> user()
    # |> Map.put_new_lazy(:location,  &location/0)
    # |> Map.put_new_lazy(:id,        &username/0)
    # |> Map.put_new_lazy(:website,   &website/0)
    # |> Map.put_new_lazy(:icon_url,  &icon_url/0)
    # |> Map.put_new_lazy(:image_url, &image_url/0)
    # |> Map.put_new(:is_followed,       false)
    # |> Map.put_new(:is_instance_admin, true)
  end
end
