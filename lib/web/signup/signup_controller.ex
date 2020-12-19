defmodule Bonfire.Me.Web.SignupController do
  use Bonfire.Web, :controller
  alias Bonfire.Me.Identity.Accounts
  alias Bonfire.Me.Web.SignupLive

  def index(conn, _), do: live_render(conn, SignupLive)

  def create(conn, params) do
    submitted = Map.get(params, "account", %{})
    attrs = %{credential: submitted, email: submitted}
    case Accounts.signup(attrs) do
      {:ok, _account} ->
        conn
        |> assign(:registered, true)
        |> live_render(SignupLive)
      {:error, :taken} ->
        conn
        |> assign(:error, :taken)
        |> live_render(SignupLive)
      {:error, changeset} ->
        conn
        |> assign(:form, changeset)
        |> assign(:error, changeset_errors_string(changeset, false))
        |> live_render(SignupLive)
    end
  end

  # TODO: move somewhere for reuse
  def changeset_errors_string(changeset, include_first_level_of_keys \\ true) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn
        {msg, opts} -> String.replace(msg, "%{count}", to_string(opts[:count]))
        msg -> msg
      end)
    error_msg = errors_map_string(errors, false)
  end

  def errors_map_string(errors, include_keys \\ true)

  def errors_map_string(%{} = errors, true) do
    Enum.map_join(errors, ", ", fn {key, val} -> "#{key} #{errors_map_string(val)}" end)
  end

  def errors_map_string(%{} = errors, false) do
    Enum.map_join(errors, ", ", fn {key, val} -> "#{errors_map_string(val)}" end)
  end

  def errors_map_string(e, _) do
    e
  end

end
