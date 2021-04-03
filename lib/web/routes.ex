defmodule Bonfire.Me.Web.Routes do
  defmacro __using__(_) do

    quote do

      alias Bonfire.Me.Web.Routes.Helpers, as: MeRoutes

      # pages anyone can view
      scope "/", Bonfire.Me.Web do
        pipe_through :browser

        live "/user/:username", ProfileLive
        live "/user/:username/:tab", ProfileLive
        live "/user/:username/posts", PostsLive

      end

      # pages only guests can view
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :guest_only
        resources "/signup", SignupController, only: [:index, :create]
        resources "/confirm-email", ConfirmEmailController, only: [:index, :create, :show]
        resources "/login", LoginController, only: [:index, :create]
        resources "/forgot-password", ForgotPasswordController, only: [:index, :create]
        resources "/reset-password", ResetPasswordController, only: [:show, :update]
      end

      # pages you need an account to view
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :account_required

        live "/dashboard", LoggedDashboardLive

        resources "/switch-user", SwitchUserController, only: [:index, :show]
        resources "/create-user", CreateUserController, only: [:index, :create]

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

        live "/user", ProfileLive

        live "/settings", SettingsLive

        live "/user/circles", CirclesLive

        # resources "/settings/user/delete", UserDeleteController, only: [:index, :create]
      end

      # pages only admins can view
      scope "/settings", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :admin_required
        live "/", InstanceSettingsLive
      end


    end
  end
end
