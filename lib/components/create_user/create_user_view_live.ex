defmodule Bonfire.UI.Me.CreateUserViewLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop form, :any
  prop suggested_name, :string, default: ""

  # "organisation" makes this an org shared-user profile (shows the label field, carried through on submit); nil/otherwise is a personal profile
  prop type, :string, default: nil
  prop label, :string, default: nil

  # the account's existing personas, for choosing the org's first co-manager (see create_user_view_live.sface)
  prop account_users, :list, default: []

  @doc "Default label for the optional extra-consent checkbox (used when the instance enables it via `[:terms, :extra_consent]` set to `true`)."
  def default_extra_consent_text,
    do:
      l(
        "I am aware that political opinions may be revealed through my participation and contributions; I expressly consent to this processing."
      )

  @doc """
  Resolves the single `[:terms, :extra_consent]` instance setting to the checkbox label to show during signup, or `nil` when the extra consent is disabled:
  - `nil` / `false` / `""` → `nil` (disabled)
  - `true` → the `default_extra_consent_text/0`
  - any other non-empty string → that custom text
  """
  def extra_consent_text do
    case Config.get([:terms, :extra_consent], nil) do
      value when value in [nil, "nil", false, "false", ""] -> nil
      value when value in [true, "true"] -> default_extra_consent_text()
      text when is_binary(text) -> text
      _ -> nil
    end
  end

  @doc "Whether the optional extra-consent checkbox should be shown and required during signup."
  def extra_consent_enabled?, do: extra_consent_enabled?(extra_consent_text())

  @doc "Same as `extra_consent_enabled?/0` but reuses an already-resolved `extra_consent_text/0` value to avoid re-reading the setting."
  def extra_consent_enabled?(resolved_text), do: not is_nil(resolved_text)

  @doc "The instance's CUSTOM extra-consent override text, or `\"\"` when disabled or using the default text (stored as `true`). Used to pre-fill the Terms editor without echoing the default placeholder text (and without losing a stored override on save)."
  def extra_consent_custom_text do
    case Config.get([:terms, :extra_consent], nil) do
      text when is_binary(text) and text not in ["", "true", "false"] -> text
      _ -> ""
    end
  end
end
