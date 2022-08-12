defmodule Bonfire.UI.Me.Routes do
  defmacro __using__(_) do

    quote do

      # pages anyone can view
      scope "/", Bonfire.UI.Me do
        pipe_through :browser

        # order matters!
        live "/@:username/:tab", ProfileLive, as: Bonfire.Data.Identity.User
        live "/@:username", ProfileLive, as: Bonfire.Data.Identity.User
        live "/user/", ProfileLive, as: Bonfire.Data.Identity.User

        live "/user/@:username", ProfileLive
        live "/user/:username", ProfileLive, as: :user_profile
        live "/user/:id", ProfileLive, as: :user_profile
        live "/user/:username/:tab", ProfileLive, as: :user_profile

        live "/profile/:id", CharacterLive, as: Bonfire.Data.Social.Profile
        live "/character/:id", CharacterLive, as: Bonfire.Data.Identity.Character
        live "/profile/:username", CharacterLive, as: Bonfire.Data.Social.Profile
        live "/character/:username", CharacterLive, as: Bonfire.Data.Identity.Character

        resources "/login/forgot-password", ForgotPasswordController, only: [:index, :create], as: :forgot_password

        live "/users", UsersDirectoryLive

      end

      # pages only guests can view
      scope "/", Bonfire.UI.Me do
        pipe_through :browser
        pipe_through :guest_only
        resources "/signup", SignupController, only: [:index, :create], as: :signup
        resources "/signup/invitation/:invite", SignupController, only: [:index, :create], as: :invite
        resources "/signup/email/confirm", ConfirmEmailController, only: [:index, :create, :show]
        resources "/signup/email/confirm/:id", ConfirmEmailController, only: [:show]
        resources "/login", LoginController, only: [:index, :create], as: :login
        resources "/login/forgot-password/:login_token", ForgotPasswordController, only: [:index]
        resources "/login/:login_token", LoginController, only: [:index]
      end

      scope "/", Bonfire do
        pipe_through :browser
        pipe_through :account_required

        live "/settings/extensions/diff", UI.Common.ExtensionDiffLive

      end

      # pages you need an account to view
      scope "/", Bonfire.UI.Me do
        pipe_through :browser
        pipe_through :account_required

        # live "/dashboard", LoggedDashboardLive, as: :dashboard

        resources "/switch-user", SwitchUserController, only: [:index, :show], as: :switch_user
        resources "/create-user", CreateUserController, only: [:index, :create], as: :create_user

        # live "/account/password/change", ChangePasswordLive
        resources "/account/password/change", ChangePasswordController, only: [:index, :create], as: :change_password

        live "/settings/:tab", SettingsLive
        live "/settings/:tab/:id", SettingsLive
        live "/settings/:tab/:id/:section", SettingsLive, as: :settings

        # resources "/settings/account/delete", AccountDeleteController, only: [:index, :create]

        resources "/logout", LogoutController, only: [:index, :create]
      end

      # pages you need to view as a user
      scope "/", Bonfire.UI.Me do
        pipe_through :browser
        pipe_through :user_required

        live "/user", ProfileLive, as: :user_profile
        live "/settings", SettingsLive

        live "/user/circles", CirclesLive

        # resources "/settings/user/delete", UserDeleteController, only: [:index, :create]
      end

      # pages only admins can view
      scope "/", Bonfire.UI.Me do
        pipe_through :browser
        pipe_through :admin_required

        live "/settings/", SettingsLive, as: :admin_settings
      end

    end
  end
end
