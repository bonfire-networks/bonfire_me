defmodule Bonfire.Me.Web.Routes do
  defmacro __using__(_) do

    quote do

      # pages anyone can view
      scope "/", Bonfire.Me.Web do
        pipe_through :browser

        live "/user/:username", ProfileLive, as: Bonfire.Data.Identity.User
        live "/user/:username/:tab", ProfileLive
        live "/user/:username/posts", PostsLive

      end

      # pages only guests can view
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :guest_only
        resources "/signup", SignupController, only: [:index, :create], as: :signup
        resources "/confirm-email", ConfirmEmailController, only: [:index, :create, :show]
        resources "/login", LoginController, only: [:index, :create], as: :login
        resources "/forgot-password", ForgotPasswordController, only: [:index, :create]
      end

      # pages you need an account to view
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :account_required

        live "/dashboard", LoggedDashboardLive, as: :dashboard

        resources "/switch-user", SwitchUserController, only: [:index, :show], as: :switch_user
        resources "/create-user", CreateUserController, only: [:index, :create], as: :create_user

        live "/change-password", ChangePasswordLive

        live "/settings/extension", SettingsLive.ExtensionDiffLive
        live "/settings/:tab", SettingsLive
        live "/settings/:tab/:id", SettingsLive

        # resources "/settings/account/delete", AccountDeleteController, only: [:index, :create]

        resources "/logout", LogoutController, only: [:index, :create]
      end

      # pages you need to view as a user
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :user_required

        live "/user", ProfileLive, as: :user_profile
        live "/private", PrivateLive, as: :user_private
        live "/settings", SettingsLive, as: :settings

        live "/user/circles", CirclesLive

        # resources "/settings/user/delete", UserDeleteController, only: [:index, :create]
      end

      # pages only admins can view
      scope "/settings", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :admin_required

        live "/admin", InstanceSettingsLive, as: :settings
      end


    end
  end
end
