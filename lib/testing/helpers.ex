defmodule Bonfire.Me.Fake.Helpers do
  use Arrows
  import Bonfire.Common.Simulation
  # import Untangle

  def confirm_token, do: Base.encode32(Faker.random_bytes(10), pad: false)
  # def location, do: Faker.Pokemon.location()
  def atusername, do: "@" <> username()

  def icon_url(_slug \\ nil), do: Faker.Internet.image_url()
  def image_url(_slug \\ nil), do: Faker.Internet.image_url()
  def avatar_url(slug), do: Faker.Avatar.image_url(slug, 140, 140)
  def avatar_url(), do: Faker.Avatar.image_url(140, 140)

  def image(%{shared_user: %{id: id, label: _}}), do: image_url(id)
  def image(%{id: id, profile: _}), do: avatar_url(id)
  def image(%{id: id, name: _}), do: avatar_url(id)
  def image(%{id: id}), do: image_url(id)
  def image(_), do: image_url()

  defp put_form_lazy(base, key, fun) do
    base
    |> Map.put(
      key,
      fun.(Map.get(base, key, %{}))
    )
  end

  def character_subform(base \\ %{}) do
    base
    # NOTE: we let the username be based off of the name (from profile) instead
    |> Map.put_new_lazy(:username, &username/0)
  end

  def credential_subform(base \\ %{}) do
    Map.put_new_lazy(base, :password, &password/0)
  end

  def email_subform(base \\ %{}) do
    Map.put_new_lazy(base, :email_address, &email/0)
  end

  def profile_subform(base \\ %{}) do
    base
    |> Map.put_new_lazy(:name, &name/0)
    |> Map.put_new_lazy(:summary, &summary/0)
    |> Map.put_new_lazy(:website, &website/0)
    |> Map.put_new_lazy(:location, &location/0)
  end

  def signup_form(base \\ %{}) do
    base
    |> put_form_lazy(:email, &email_subform/1)
    |> put_form_lazy(:credential, &credential_subform/1)
  end

  def create_user_form(base \\ %{}) do
    name = base[:username] || name()
    # we want the username to match the name for test readability
    %{name: name, username: name}
    |> Map.merge(base)
    |> Map.put(..., :profile, profile_subform(...))
    |> Map.put(..., :character, character_subform(...))
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
