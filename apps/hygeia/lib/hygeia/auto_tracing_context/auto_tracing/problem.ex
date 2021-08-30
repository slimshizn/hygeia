defmodule Hygeia.AutoTracingContext.AutoTracing.Problem do
  @moduledoc "AutoTracing Problem"

  # TODO: Add other problem cases
  use EctoEnum,
    type: :auto_tracing_problem,
    enums: [
      :unmanaged_tenant,
      :covid_app,
      :vaccination_failure,
      :hospitalization,
      :new_employer,
      :link_propagator,
      :residency_outside_country
    ]

  import HygeiaGettext

  @spec translate(problem :: t) :: String.t()
  def translate(:unmanaged_tenant), do: pgettext("Auto Tracing Problem", "Unmanaged Tenant")
  def translate(:covid_app), do: pgettext("Auto Tracing Problem", "Covid App")

  def translate(:vaccination_failure),
    do: pgettext("Auto Tracing Problem", "Vaccination Failure")

  def translate(:hospitalization), do: pgettext("Auto Tracing Problem", "Hospitalization")
  def translate(:new_employer), do: pgettext("Auto Tracing Problem", "New Employer")
  def translate(:link_propagator), do: pgettext("Auto Tracing Problem", "Link Propagator")

  def translate(:residency_outside_country),
    do: pgettext("Auto Tracing Problem", "Residency Outside Country")
end