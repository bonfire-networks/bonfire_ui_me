defmodule Bonfire.UI.Me.Routes do
  # def declare_routes, do: nil

  defmacro __using__(_) do
    quote do
      pipeline :guest_only do
        plug(Bonfire.UI.Me.Plugs.GuestOnly)
      end

      pipeline :user_required do
        plug(Bonfire.UI.Me.Plugs.LoadCurrentUser)
        plug(Bonfire.UI.Me.Plugs.UserRequired)
      end

      # an alias
      pipeline :require_authenticated_user do
        plug(Bonfire.UI.Me.Plugs.LoadCurrentUser)
        plug(Bonfire.UI.Me.Plugs.UserRequired)
      end

      pipeline :account_required do
        plug(Bonfire.UI.Me.Plugs.LoadCurrentAccount)
        plug(Bonfire.UI.Me.Plugs.AccountRequired)
      end

      pipeline :admin_required do
        plug(Bonfire.UI.Me.Plugs.AdminRequired)
      end

      # pages anyone can view
      scope "/", Bonfire.UI.Me do
        pipe_through(:browser)

        live("/error", ErrorLive, as: :error)
        live("/error/:code", ErrorLive, as: :error)

        # order matters!
        live("/@:username/:tab", ProfileLive, as: Bonfire.Data.Identity.User)
        live("/@:username", ProfileLive, as: Bonfire.Data.Identity.User)
        # live("/user/", ProfileLive, as: Bonfire.Data.Identity.User)

        live("/user/@:username", ProfileLive)
        live("/user/:id", ProfileLive, as: :user_profile)
        # live("/user/:username", ProfileLive, as: :user_profile)
        live("/user/:username/:tab", ProfileLive, as: :user_profile)

        live("/profile/:id", CharacterLive, as: Bonfire.Data.Social.Profile)
        live("/character/:id", CharacterLive, as: Bonfire.Data.Identity.Character)
        # live("/profile/:username", CharacterLive, as: Bonfire.Data.Social.Profile)
        # live("/character/:username", CharacterLive, as: Bonfire.Data.Identity.Character)

        live("/remote_interaction", RemoteInteractionLive)

        # throttle the routes below
        pipe_through(:throttle_plug_attacks)

        resources("/login/forgot-password", ForgotPasswordController,
          only: [:index, :create],
          as: :forgot_password
        )

        live("/users", UsersDirectoryLive)

        resources("/signup/email/confirm/:id", ConfirmEmailController, only: [:show])
      end

      # pages only guests can view
      scope "/", Bonfire.UI.Me do
        pipe_through([:throttle_plug_attacks, :browser, :guest_only])
        # throttling POST to the routes below

        resources("/signup", SignupController,
          only: [:index, :create],
          as: :signup
        )

        resources("/signup/invitation/:invite", SignupController,
          only: [:index, :create],
          as: :invite
        )

        resources("/signup/email/confirm", ConfirmEmailController, only: [:index, :create, :show])

        resources("/login", LoginController, only: [:index, :create], as: :login)

        resources(
          "/login/forgot-password/:login_token",
          ForgotPasswordController,
          only: [:index]
        )

        resources("/login/:login_token", LoginController, only: [:index])
      end

      scope "/", Bonfire do
        pipe_through(:browser)
        pipe_through(:account_required)

        live("/settings/extensions/diff", UI.Common.ExtensionDiffLive)
        live("/settings/extensions/code/:module", UI.Common.ViewCodeLive)
        live("/settings/extensions/code/:module/:function", UI.Common.ViewCodeLive)
      end

      # pages you need an account to view
      scope "/", Bonfire.UI.Me do
        pipe_through(:browser)
        pipe_through(:account_required)

        # live "/dashboard", LoggedDashboardLive, as: :dashboard

        resources("/switch-user", SwitchUserController,
          only: [:index, :show],
          as: :switch_user
        )

        # live "/account/password/change", ChangePasswordLive
        resources("/account/password/change", ChangePasswordController,
          only: [:index, :create],
          as: :change_password
        )

        resources("/account/email/change", ChangeEmailController,
          only: [:index, :create],
          as: :change_email
        )

        get "/settings/export/csv/:type", ExportController, :csv_download
        get "/settings/export/json/:type", ExportController, :json_download
        get "/settings/export/archive", ExportController, :archive_export
        get "/settings/export/archive_download", ExportController, :archive_download

        live("/settings", SettingsLive, :user, as: :settings)

        live("/settings/account", SettingsLive, :account, as: :account_settings)
        live("/settings/account/:tab", SettingsLive, :account, as: :account_settings)
        live("/settings/account/:tab/:id", SettingsLive, :account, as: :account_settings)
        live("/settings/account/:tab/:id/:section", SettingsLive, :account, as: :account_settings)

        live("/settings/instance", InstanceSettingsLive, :instance, as: :instance_settings)
        live("/settings/instance/:tab", InstanceSettingsLive, :instance, as: :instance_settings)

        live("/settings/instance/:tab/:id", InstanceSettingsLive, :instance,
          as: :instance_settings
        )

        live("/settings/instance/:tab/:id/:section", InstanceSettingsLive, :instance,
          as: :instance_settings
        )

        # resources "/settings/account/delete", AccountDeleteController, only: [:index, :create]

        resources("/logout", LogoutController, only: [:index, :create])

        # throttling POST to the routes below
        pipe_through(:throttle_plug_attacks)

        resources("/create-user", CreateUserController,
          only: [:index, :create],
          as: :create_user
        )
      end

      # pages you need to view as a user
      scope "/", Bonfire.UI.Me do
        pipe_through(:browser)
        pipe_through(:user_required)

        live("/user", ProfileLive, as: Bonfire.Data.Identity.User)

        live("/settings/user/:tab", SettingsLive, :user, as: :user_settings)
        live("/settings/user/:tab/:id", SettingsLive, :user, as: :user_settings)
        live("/settings/user/:tab/:id/:section", SettingsLive, :user, as: :user_settings)

        live("/user/circles", CirclesLive)

        # resources "/settings/user/delete", UserDeleteController, only: [:index, :create]
      end

      # pages only admins can view
      scope "/", Bonfire.UI.Me do
        pipe_through(:browser)
        pipe_through(:admin_required)

        # live("/settings/", SettingsLive, as: :admin_settings)
      end
    end
  end
end
