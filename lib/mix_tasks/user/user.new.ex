## About half of this code is taken from hex, therefore this whole
## file is considered under the same license terms as hex.
defmodule Mix.Tasks.Bonfire.User.New do
  use Mix.Task

  @shortdoc "Creates a new user in the database"

  @moduledoc """
  Creates an user in the database (and an account, automatically activated)

  ## Usage

  ```
  just mix bonfire.user.new [username] [email@address]
  ```

  You will be prompted for a password, and username/email if not provided.
  """

  alias Bonfire.Me

  @spec run(OptionParser.argv()) :: :ok
  def run(args) do
    options = options(args, %{})
    Mix.Task.run("app.start")
    username = Mix.Tasks.Bonfire.Account.New.get("Choose a username: ", :username, options, true)
    email = Mix.Tasks.Bonfire.Account.New.get("Enter an email address: ", :email, options, true)
    password = Mix.Tasks.Bonfire.Account.New.password("Enter a password:")
    IO.puts("Chosen password: #{password}")

    Me.make_account_and_user(username, email, password)
  end

  defp options([], opts), do: opts

  defp options([username, email], opts),
    do: opts |> Map.put(:username, username) |> Map.put(:email, email)

  defp options([username], opts), do: Map.put(opts, :username, username)
end
