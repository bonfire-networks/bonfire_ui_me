defmodule Bonfire.Me.Social.Settings.PushNotificationsLive do
  @moduledoc """
  User settings component for push notifications.
  Allows users to enable/disable push notifications and manage registered devices.
  """

  use Bonfire.UI.Common.Web, :stateful_component

  alias Bonfire.Notify.WebPush

  prop scope, :any, default: nil

  data vapid_public_key, :string, default: nil
  data subscriptions, :list, default: []
  data push_supported, :boolean, default: true
  data current_device_subscribed, :boolean, default: false
  data current_endpoint, :string, default: nil

  def update(assigns, socket) do
    # Assign first so __context__ is available
    socket = assign(socket, assigns)

    vapid_public_key = Application.get_env(:ex_nudge, :vapid_public_key)
    # Try assigns first, then socket for current_user
    user = current_user(assigns) || current_user(socket)

    subscriptions =
      if user && vapid_public_key do
        WebPush.list_subscriptions(id(user))
      else
        []
      end

    {:ok,
     socket
     |> assign(:vapid_public_key, vapid_public_key)
     |> assign(:subscriptions, subscriptions)}
  end

  # Handle enable push button click - triggers JS to request browser permission
  def handle_event("enable_push", _params, socket) do
    vapid_key = socket.assigns.vapid_public_key
    {:noreply, push_event(socket, "request_push_permission", %{vapid_key: vapid_key})}
  end

  # Handle disable push button click - triggers JS to unsubscribe
  def handle_event("disable_push", _params, socket) do
    {:noreply, push_event(socket, "request_push_disable", %{})}
  end

  # Check if current browser's subscription is registered on the server
  def handle_event("check_subscription", %{"endpoint" => endpoint}, socket) do
    subscriptions = socket.assigns[:subscriptions] || []
    is_subscribed = Enum.any?(subscriptions, fn sub -> sub.endpoint == endpoint end)

    {:noreply,
     socket
     |> assign(:current_device_subscribed, is_subscribed)
     |> assign(:current_endpoint, endpoint)}
  end

  # Handle subscription data received from JS hook after browser grants permission
  def handle_event("push_subscription_created", %{"subscription" => subscription_data}, socket) do
    user = current_user(socket.assigns)

    if user do
      user_id = id(user)

      case WebPush.subscribe(user_id, subscription_data) do
        {:ok, _subscription} ->
          subscriptions = WebPush.list_subscriptions(user_id)

          {:noreply,
           socket
           |> assign(:subscriptions, subscriptions)
           |> assign(:current_device_subscribed, true)
           |> put_flash(:info, l("Push notifications enabled for this device"))}

        {:error, changeset} ->
          error_msg = format_changeset_errors(changeset)

          {:noreply, put_flash(socket, :error, l("Failed to enable notifications: %{error}", error: error_msg))}
      end
    else
      {:noreply, put_flash(socket, :error, l("You must be logged in to enable push notifications"))}
    end
  end

  # Handle when JS successfully disables push subscription
  def handle_event("push_subscription_disabled", %{"endpoint" => endpoint}, socket) do
    # Remove the subscription from the server
    case WebPush.remove_subscription_by_endpoint(endpoint) do
      {count, _} when count > 0 ->
        user = current_user(socket.assigns)

        subscriptions =
          if user do
            WebPush.list_subscriptions(id(user))
          else
            []
          end

        {:noreply,
         socket
         |> assign(:subscriptions, subscriptions)
         |> assign(:current_device_subscribed, false)
         |> put_flash(:info, l("Push notifications disabled for this device"))}

      _ ->
        {:noreply,
         socket
         |> assign(:current_device_subscribed, false)
         |> put_flash(:info, l("Push notifications disabled"))}
    end
  end

  def handle_event("push_subscription_error", %{"error" => error}, socket) do
    {:noreply, put_flash(socket, :error, l("Failed to enable notifications: %{error}", error: error))}
  end

  # Handle remove device
  def handle_event("remove_device", %{"id" => device_id}, socket) do
    case WebPush.remove_subscription(device_id) do
      {:ok, _} ->
        user = current_user(socket.assigns)

        subscriptions =
          if user do
            WebPush.list_subscriptions(id(user))
          else
            []
          end

        # Check if current device is still in the list
        current_endpoint = socket.assigns[:current_endpoint]

        current_device_subscribed =
          if current_endpoint do
            Enum.any?(subscriptions, fn sub -> sub.endpoint == current_endpoint end)
          else
            false
          end

        {:noreply,
         socket
         |> assign(:subscriptions, subscriptions)
         |> assign(:current_device_subscribed, current_device_subscribed)
         |> put_flash(:info, l("Device removed"))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, l("Failed to remove device: %{error}", error: inspect(reason)))}
    end
  end

  # Handle push not supported
  def handle_event("push_not_supported", _params, socket) do
    {:noreply, assign(socket, :push_supported, false)}
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {message, _}} ->
      "#{field}: #{message}"
    end)
  end

  defp format_changeset_errors(other), do: inspect(other)

  @doc false
  def browser_from_endpoint(endpoint) when is_binary(endpoint) do
    cond do
      String.contains?(endpoint, "mozilla.com") -> "Firefox"
      String.contains?(endpoint, "fcm.googleapis.com") -> "Chrome"
      String.contains?(endpoint, "push.apple.com") -> "Safari"
      String.contains?(endpoint, "notify.windows.com") -> "Edge"
      true -> "Browser"
    end
  end

  def browser_from_endpoint(_), do: "Browser"

  @doc false
  def short_id(endpoint) when is_binary(endpoint) do
    # Generate a short ID from the last part of the endpoint URL
    endpoint
    |> String.split("/")
    |> List.last()
    |> String.slice(0, 8)
  end

  def short_id(_), do: ""

  @doc false
  def is_current_device?(sub, current_endpoint) do
    sub.endpoint == current_endpoint
  end
end
