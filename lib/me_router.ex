defmodule Bonfire.Me.Web.Router do
  defmacro __using__(_) do

    quote do

      # alias Bonfire.Me.Web.Router.Helpers, as: MeRoutes


      # visible to everyone
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        live "/", IndexLive, :index
        live "/users/@:username", ProfileLive, :profile
        live "/users/@:username/:tab", ProfileLive, :profile_tab
      end

      # visible only to guests
      scope "/", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :guest_only
        # guest visible pages
        resources "/confirm-email", ConfirmEmailController, only: [:index, :show, :create]
        resources "/signup", SignupController, only: [:index, :create]
        resources "/login", LoginController, only: [:index, :create]
        resources "/forgot-password/", ForgotPasswordController, only: [:index, :create]
        resources "/reset-password/:token", ResetPasswordController, only: [:index, :create]
      end

      # visible only to users and account holders
      scope "/~", Bonfire.Me.Web do
        pipe_through :browser
        pipe_through :auth_required
        live "/", SwitchUserLive
        live "/change-password", ChangePasswordLive
        live "/create-user", CreateUserLive, only: [:index, :create]

        scope "/@:username" do
          live "/home", HomeLive, :home
          live "/settings", SettingsLive, :settings
          live "/settings/:tab", SettingsLive, :settings_tab
        end
      end


    end
  end
end
