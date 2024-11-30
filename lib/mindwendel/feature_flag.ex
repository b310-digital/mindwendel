defmodule Mindwendel.FeatureFlag do
  @moduledoc """
  Support for checking feature flags.

  Feature flags are defined under the `:options` key for `:mindwendel` in the config.
  If a flag isn't set it is treated as deactivated.
  """

  def enabled?(flag_name) do
    :mindwendel
    |> Application.fetch_env!(:options)
    |> Access.get(flag_name)
  end
end
