defmodule Bonfire.UI.Me.Routes do
  # def declare_routes, do: nil

  defmacro __using__(_) do
    quote do
      pipeline :early_hints_authed do
        plug PlugEarlyHints, paths: Bonfire.UI.Common.Routes.early_hints_authed()
      end

      pipeline :guest_only do
        plug(Bonfire.UI.Me.Plugs.GuestOnly)
      end

      pipeline :user_required do
        plug PlugEarlyHints, paths: Bonfire.UI.Common.Routes.early_hints_authed()

        plug(Bonfire.UI.Me.Plugs.LoadCurrentUser)
        plug(Bonfire.UI.Me.Plugs.UserRequired)
      end

      # an alias of :user_required
      pipeline :require_authenticated_user do
        plug PlugEarlyHints, paths: Bonfire.UI.Common.Routes.early_hints_authed()

        plug(Bonfire.UI.Me.Plugs.LoadCurrentUser)
        plug(Bonfire.UI.Me.Plugs.UserRequired)
      end

      pipeline :account_required do
        plug PlugEarlyHints, paths: Bonfire.UI.Common.Routes.early_hints_authed()

        # plug(Bonfire.UI.Me.Plugs.LoadCurrentAccount)
        # ^ no need to call LoadCurrentAccount if also calling LoadCurrentUser
        plug(Bonfire.UI.Me.Plugs.LoadCurrentUser)

        # ^ because even though we only required the account we may want to know the user, and also we prefer having the account within `current_user` in assigns
        plug(Bonfire.UI.Me.Plugs.AccountRequired)
      end

      pipeline :admin_required do
        plug(Bonfire.UI.Me.Plugs.LoadCurrentUser)
        plug(Bonfire.UI.Me.Plugs.AdminRequired)
      end

      # pages anyone can view
      scope "/", Bonfire.UI.Me do
        pipe_through(:browser)

        live("/error", ErrorLive, as: :error)
        live("/error/:code", ErrorLive, as: :error)

        # order matters!
        live("/@:username/:tab", ProfileLive, as: Bonfire.Data.Identity.User)
        live("/@:username/:tab/:extra", ProfileLive, as: Bonfire.Data.Identity.User)
        live("/@:username", ProfileLive, as: Bonfire.Data.Identity.User)
        # live("/user/", ProfileLive, as: Bonfire.Data.Identity.User)

        live("/user/@:username", ProfileLive)
        live("/user/:id", ProfileLive, as: :user_profile)
        # live("/user/:username", ProfileLive, as: :user_profile)
        live("/user/:username/:tab", ProfileLive, as: :user_profile)

        live("/profile/:id", ProfileLive, as: Bonfire.Data.Social.Profile)
        live("/character/:id", CharacterLive, as: Bonfire.Data.Identity.Character)
        live("/username/:username", Bonfire.UI.Me.CharacterLive, as: Bonfire.UI.Me.CharacterLive)
        # live("/profile/:username", CharacterLive, as: Bonfire.Data.Social.Profile)
        # live("/character/:username", CharacterLive, as: Bonfire.Data.Identity.Character)

        live("/remote_interaction", RemoteInteractionLive)

        get "/settings/deleted/account/:id", DeletedController, :account
        get "/settings/deleted/user/:id", DeletedController, :user
        get "/settings/deleted/:type/:id", DeletedController, :other

        # throttle the routes below
        pipe_through(:throttle_plug_attacks)

        resources("/login/forgot-password", ForgotPasswordController,
          only: [:index, :create],
          as: :forgot_password
        )

        live("/users", UsersDirectoryLive)
        live("/users/instance/:instance", UsersDirectoryLive)
        live("/users/instance/:display_name/:instance", UsersDirectoryLive)
        live("/known_instances", InstancesDirectoryLive)

        resources("/signup/email/confirm/:id", ConfirmEmailController, only: [:show])
      end

      scope "/api" do
        pipe_through(:basic_json)
        pipe_through(:throttle_plug_attacks)

        get "/v0/user", Bonfire.UI.Me.API.GraphQL.RestAdapter, :user
        get "/v0/me", Bonfire.UI.Me.API.GraphQL.RestAdapter, :me
      end

      # pages only guests can view
      scope "/", Bonfire.UI.Me do
        pipe_through([:throttle_plug_attacks, :browser, :guest_only])
        # throttling POST to the routes below

        resources("/signup", SignupController,
          only: [:index, :create],
          as: :signup
        )

        # alias for Masto clients
        resources("/auth/sign_up", SignupController,
          only: [:index, :create],
          as: :signup
        )

        resources("/signup/invitation/:invite", SignupController,
          only: [:index, :create],
          as: :invite
        )

        resources("/signup/email/confirm", ConfirmEmailController, only: [:index, :create, :show])

        resources(
          "/login/forgot-password/:login_token",
          ForgotPasswordController,
          only: [:index]
        )

        # tell the browser to preload the LiveView JS when logging in
        pipe_through(:early_hints_authed)

        resources("/login", LoginController, only: [:index, :create], as: :login)

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
        get "/settings/export/binary/:type/:ext", ExportController, :binary_download
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

        get "/settings/export/archive_delete", ExportController, :archive_delete
      end
    end
  end
end
