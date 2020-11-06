use Mix.Config

# You will almost certainly want to copy this into your app's config,
# and then change at least some of the values

config :cpub_me, :repo_module, MyApp.Repo
config :cpub_me, :mailer_module, MyApp.Mailer
config :cpub_me, :web_module, CommonsPub.Core.Web
config :cpub_me, :helper_module, CommonsPub.Core.WebHelpers
config :cpub_me, :templates_path, "lib/web"

config :cpub_me, CommonsPub.Me.Accounts.Emails,
  confirm_email: [subject: "Confirm your email on CommonsPub"],
  reset_password: [subject: "Reset your password on CommonsPub"]

#### Pointers configuration

# This tells `Pointers.Tables` which apps to search for tables to
# index. If you add another dependency with Pointables, you will want
# to add it to the search path

config :pointers,
  search_path: [
    :cpub_accounts,
    :cpub_characters,
    :cpub_emails,
    :cpub_local_auth,
    :cpub_profiles,
    :cpub_users,
    :cpub_me,
  ]

#### Flexto Stitching

## WARNING: This is the flaky magic bit. We use configuration to
## compile extra stuff into modules.  If you add new fields or
## relations to ecto models in a dependency, you must recompile that
## dependency for it to show up! You will probably find you need to
## `rm -Rf _build/*/lib/cpub_*` a lot.

## Note: This does not apply to configuration for
## `Pointers.Changesets`, which is read at runtime, not compile time

alias CommonsPub.{
  Accounts.Account,
  Accounts.Accounted,
  Characters.Character,
  Comments.Comment,
  Communities.Communities,
  Circles.Circle,
  Emails.Email,
  Features.Feature,
  Follows.Follow,
  Likes.Like,
  LocalAuth.LoginCredential,
  Profiles.Profile,
  Threads.Thread,
  Users.User,
}

config :cpub_accounts, Account,
  has_one: [email:            {Email,           foreign_key: :id}],
  has_one: [login_credential: {LoginCredential, foreign_key: :id}],
  has_many: [accounted: Accounted],
  has_many: [users:     [through: [:accounted, :user]]]

config :cpub_accounts, Accounted,
  belongs_to: [user: {User, foreign_key: :id, define_field: false}]

config :cpub_characters, Character,
  belongs_to: [user: {User, foreign_key: :id, define_field: false}]

config :cpub_emails, Email,
  belongs_to: [account: {Account, foreign_key: :id, define_field: false}]

config :cpub_local_auth, LoginCredential,
  belongs_to: [account: {Account, foreign_key: :id, define_field: false}],
  rename_attrs: [email: :identity],
  password: [length: [min: 8, max: 64]]

config :cpub_profiles, Profile,
  belongs_to: [user: {User, foreign_key: :id, define_field: false}]

config :cpub_users, User,
  has_one: [accounted: {Accounted, foreign_key: :id}],
  has_one: [character: {Character, foreign_key: :id}],
  has_one: [profile:   {Profile,   foreign_key: :id}],
  has_one: [actor:     {Actor,     foreign_key: :id}]

#### Forms configuration

# You probably will want to leave these

alias CommonsPub.Me.Accounts.{
  ChangePasswordFields,
  ConfirmEmailFields,
  LoginFields,
  ResetPasswordFields,
  SignupFields,
}
alias CommonsPub.Me.Users.UserFields

# these are not used yet, but they will be

config :cpub_me, ChangePasswordFields,
  cast: [:old_password, :password, :password_confirmation],
  required: [:old_password, :password, :password_confirmation],
  confirm: :password,
  new_password: [length: [min: 10, max: 64]]

config :cpub_me, ConfirmEmailFields,
  cast: [:email],
  required: [:email],
  email: [format: ~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$)]

config :cpub_me, LoginFields,
  cast: [:email, :password],
  required: [:email, :password],
  email: [format: ~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$)],
  password: [length: [min: 10, max: 64]]

config :cpub_me, ResetPasswordFields,
  cast: [:password, :password_confirmation],
  required: [:password, :password_confirmation],
  confirm: :password,
  password: [length: [min: 10, max: 64]]

config :cpub_me, SignupFields,
  cast: [:email, :password],
  required: [:email, :password],
  email: [format: ~r(^[^@]{1,128}@[^@\.]+\.[^@]{2,128}$)],
  password: [length: [min: 10, max: 64]]

config :cpub_me, UserFields,
  username: [format: ~r(^[a-z][a-z0-9_]{2,30}$)i],
  name: [length: [min: 3, max: 50]],
  summary: [length: [min: 20, max: 500]]

#### Basic configuration

# You probably won't want to copy these to your app or change them.
# You might override some in other config files.

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :mime, :types, %{
  "application/activity+json" => ["activity+json"]
}

# import_config "#{Mix.env()}.exs"
