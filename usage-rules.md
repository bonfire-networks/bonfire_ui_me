# Bonfire.UI.Me Usage Rules

Bonfire.UI.Me provides the foundational UI layer for user authentication, profile management, and account settings in Bonfire applications. These rules ensure proper integration with the authentication system while maintaining security and consistency.

## Core Concepts

### Authentication Pipelines
Pipeline-based authentication and authorization system that protects routes and LiveViews:

```elixir
# Available pipelines
:guest_only      # Only non-authenticated users (login/signup pages)
:user_required   # Requires authenticated user
:account_required # Requires account ownership
:admin_required  # Requires admin privileges
```

### Profile Components
Reusable Surface components for displaying and managing user profiles with flexible customization options.

### Settings System
Scoped configuration system that supports user, account, and instance-level settings with proper permission checking.

## Core Module Setup

Always use the provided module templates for consistency:

```elixir
# For LiveView components
defmodule MyApp.ProfileCustomLive do
  use Bonfire.UI.Common.Web, :stateless_component
  # or
  use Bonfire.UI.Common.Web, :stateful_component
end

# For route modules
defmodule MyApp.Routes do
  def declare_routes, do: quote do
    scope "/" do
      pipe_through(:user_required)
      live("/my-page", MyApp.MyPageLive)
    end
  end
end
```

## Authentication Patterns

### Protecting Routes

Use authentication pipelines in your router:

```elixir
# Public pages
scope "/" do
  pipe_through(:browser)
  live("/about", AboutLive)
end

# User-only pages
scope "/user" do
  pipe_through(:user_required)
  live("/dashboard", DashboardLive)
end

# Admin-only pages
scope "/admin" do
  pipe_through(:admin_required)
  live("/settings", AdminSettingsLive)
end
```

### Loading Current User in LiveView

Always load the current user in your LiveView mounts:

```elixir
defmodule MyApp.MyPageLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}
  
  def mount(params, session, socket) do
    current_user = current_user(socket)
    # current_user is now available
    {:ok, socket}
  end
end
```

### Requiring Authentication

For pages that require authentication:

```elixir
defmodule MyApp.SecurePageLive do
  use Bonfire.UI.Common.Web, :surface_live_view
  on_mount {LivePlugs, [
    Bonfire.UI.Me.LivePlugs.LoadCurrentUser,
    Bonfire.UI.Me.LivePlugs.UserRequired
  ]}
end
```

## Profile Component Usage

### Basic Profile Display

```elixir
# Minimal profile item
<Bonfire.UI.Me.ProfileItemLive
  profile={@user.profile}
  character={@user.character}
/>

# Profile with controls
<Bonfire.UI.Me.ProfileItemLive
  profile={@user.profile}
  character={@user.character}
  show_controls={[:follow, :message]}
  wrapper_class="p-4 border rounded"
/>

# Compact user preview
<Bonfire.UI.Me.UserPreviewLive
  user={@user}
  avatar_size="small"
  show_summary={false}
/>
```

### Full Profile Hero

```elixir
<Bonfire.UI.Me.ProfileHeroFullLive
  user={@user}
  current_user={current_user(@__context__)}
  page={@page}
  selected_tab={@selected_tab}
  profile_sections={@profile_sections}
/>
```

## Settings Management

### User Preferences

```elixir
# Basic preferences component
<Bonfire.UI.Me.SettingsViewsLive.PreferencesLive
  scope={:user}
  current_user={current_user(@__context__)}
/>

# Extension-specific settings
<Bonfire.UI.Me.SettingsViewsLive.ExtensionSettingsLive
  extension={:my_extension}
  scope={:user}
  current_user={current_user(@__context__)}
/>
```

### Scoped Settings Access

```elixir
# Get scoped settings with permission checking
def handle_event("update_setting", %{"key" => key, "value" => value}, socket) do
  scope = :user  # or :instance, :account
  scoped = Bonfire.Common.Settings.LiveHandler.scoped(scope, socket.assigns)
  
  if can_edit_settings?(scoped, socket.assigns) do
    Settings.put(key, value, scope, socket.assigns.current_user)
  end
end
```

## Event Handling

### Using Shared Live Handlers

Delegate to shared handlers for common user operations:

```elixir
defmodule MyApp.UsersLive do
  def handle_event("autocomplete", params, socket) do
    Bonfire.Me.Users.LiveHandler.handle_event("autocomplete", params, socket)
  end
  
  def handle_event("user_follow", %{"id" => id}, socket) do
    with {:ok, _} <- Bonfire.Social.Graph.Follows.follow(
      current_user(socket),
      id
    ) do
      {:noreply, socket |> put_flash(:info, "Followed!")}
    end
  end
end
```

### Profile Management Events

```elixir
def handle_event("profile_save", %{"profile" => profile_params}, socket) do
  Bonfire.Me.Profiles.LiveHandler.handle_event(
    "profile_save",
    profile_params,
    socket
  )
end
```

## Component Integration

### Including UI.Me Components

Always check component availability:

```elixir
# Stateless component
<StatelessComponent
  module={maybe_component(Bonfire.UI.Me.ProfileItemLive, @__context__)}
  user={@user}
/>

# Stateful component with ID
<StatefulComponent
  id="user-settings"
  module={maybe_component(Bonfire.UI.Me.SettingsViewsLive.PreferencesLive, @__context__)}
  scope={:user}
/>
```

### Navigation Components

```elixir
# Settings sidebar navigation
<Bonfire.UI.Me.SettingsNavLive
  current_user={current_user(@__context__)}
  selected_tab={@selected_tab}
  scope={@scope}
/>

# User switcher in menu
<Bonfire.UI.Me.SwitchUserMenuItemsLive
  current_account={current_account(@__context__)}
  current_user={current_user(@__context__)}
/>
```

## Form Handling

### Login Form

```elixir
<Bonfire.UI.Me.LoginViewLive
  form={@form}
  error_message={@error_message}
  action={~p"/login"}
/>
```

### Signup Form

```elixir
<Bonfire.UI.Me.SignupFormLive
  form={@form}
  action={~p"/signup"}
  invite={@invite}
/>
```

### Profile Edit Form

```elixir
<Bonfire.UI.Me.EditProfileLive
  user={@current_user}
  uploads={@uploads}
  uploaded_files={@uploaded_files}
/>
```

## Error Handling

### Authentication Errors

```elixir
case Bonfire.Me.Users.login(email, password) do
  {:ok, user} ->
    {:noreply, socket |> redirect(to: ~p"/")}
    
  {:error, :invalid_credentials} ->
    {:noreply, socket |> put_flash(:error, l("Invalid email or password"))}
    
  {:error, :account_disabled} ->
    {:noreply, socket |> put_flash(:error, l("This account has been disabled"))}
end
```

### Permission Errors

```elixir
if Bonfire.Boundaries.can?(socket.assigns.__context__, :configure, :instance) do
  # Show admin interface
else
  {:noreply, socket |> put_flash(:error, l("You don't have permission"))}
end
```

## Testing

### Testing Authentication

```elixir
test "requires authentication", %{conn: conn} do
  conn = get(conn, "/protected")
  assert redirected_to(conn) == "/login"
end

test "loads current user", %{conn: conn} do
  user = fake_user!()
  conn = log_in_user(conn, user)
  conn = get(conn, "/dashboard")
  assert html_response(conn, 200) =~ user.profile.name
end
```

### Testing Components

```elixir
test "profile component renders", %{conn: conn} do
  user = fake_user!()
  {:ok, view, _html} = live_isolated(
    conn,
    Bonfire.UI.Me.ProfileItemLive,
    session: %{"current_user_id" => user.id}
  )
  
  assert has_element?(view, "[data-id=profile-#{user.id}]")
end
```

## Performance Best Practices

### Preload User Data

```elixir
# Preload associations to avoid N+1 queries
users = Users.list_paginated(
  preload: [:profile, :character, account: [:settings]]
)
```

### Component Memoization

```elixir
# Cache expensive computations
def render(assigns) do
  assigns = assign_new(assigns, :formatted_bio, fn ->
    format_markdown(assigns.user.profile.bio)
  end)
  
  ~F"""
  <div>{@formatted_bio}</div>
  """
end
```

## Security Best Practices

### Always Check Permissions

```elixir
# ✅ Good
if can?(socket.assigns, :edit, user) do
  do_edit(user)
end

# ❌ Bad
do_edit(user)  # No permission check!
```

### Validate User Context

```elixir
# ✅ Good
def handle_event("delete", %{"id" => id}, socket) do
  user = current_user_required!(socket)
  if user.id == id or can?(socket.assigns, :delete, id) do
    # Allow deletion
  end
end

# ❌ Bad
def handle_event("delete", %{"id" => id}, socket) do
  Users.delete(id)  # No authorization!
end
```

## Common Anti-Patterns to Avoid

### ❌ Direct User Access
```elixir
# Bad
socket.assigns.current_user.id

# Good
current_user_id(socket)
```

### ❌ Missing Authentication Pipeline
```elixir
# Bad
live("/admin", AdminLive)

# Good
scope "/admin" do
  pipe_through(:admin_required)
  live("/", AdminLive)
end
```

### ❌ Hardcoded Component Paths
```elixir
# Bad
<Bonfire.UI.Me.ProfileItemLive user={@user} />

# Good
<StatelessComponent
  module={maybe_component(Bonfire.UI.Me.ProfileItemLive, @__context__)}
  user={@user}
/>
```

### ❌ Missing Context
```elixir
# Bad
Settings.get(:my_setting, :user)

# Good
Settings.get(:my_setting, :user, current_user(socket))
```

## Debugging

### User Loading Issues

```elixir
# Check if user is loaded
IO.inspect(socket.assigns[:current_user], label: "Current user")
IO.inspect(socket.assigns[:current_account], label: "Current account")

# Verify authentication pipeline
IO.inspect(socket.private[:phoenix_live_view][:live_module])
```

### Permission Debugging

```elixir
# Check specific permissions
can? = Bonfire.Boundaries.can?(socket.assigns, :edit, resource)
debug(can?, "Can edit?")

# List user's roles
roles = Bonfire.Boundaries.Roles.list_by_user(current_user(socket))
debug(roles, "User roles")
```

## Integration with Other Extensions

### Social Features

```elixir
# Following status in profiles
<Bonfire.UI.Me.ProfileItemLive
  user={@user}
  current_user={current_user(@__context__)}
  show_controls={[:follow]}
  following={Bonfire.Social.Graph.Follows.following?(@current_user, @user)}
/>
```

### Boundaries Integration

```elixir
# Permission-aware settings
if can?(@__context__, :configure, :extensions) do
  <Bonfire.UI.Me.SettingsViewsLive.ExtensionSettingsLive 
    scope={:instance}
    extension={:my_extension}
  />
end
```

### Activity Feeds

```elixir
# User activity feed
<Bonfire.UI.Social.FeedLive
  feed_id={{:user, @user.id}}
  current_user={current_user(@__context__)}
/>
```

Remember: Bonfire.UI.Me provides the authentication and user management foundation. Always use its patterns for consistent security and user experience across your Bonfire application.