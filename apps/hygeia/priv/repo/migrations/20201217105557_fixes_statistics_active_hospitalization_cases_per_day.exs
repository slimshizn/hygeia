# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule Hygeia.Repo.Migrations.FixesStatisticsActiveHospitalizationCasesPerDay do
  @moduledoc false

  use Hygeia, :migration

  # Only up on purpose
  def up do
    execute("""
    DROP MATERIALIZED VIEW statistics_active_hospitalization_cases_per_day;
    """)

    execute("""
      CREATE MATERIALIZED VIEW statistics_active_hospitalization_cases_per_day
        (tenant_uuid, date, count)
        AS WITH cases_with_hospitalizations AS (
          SELECT
            cases.tenant_uuid,
            cases.person_uuid,
            (hospitalization->>'start')::date AS start_date,
            COALESCE(
              (hospitalization->>'end')::date,
              (cases.phases[ARRAY_UPPER(cases.phases,1)]->>'end')::date,
              CURRENT_DATE
            ) AS end_date
          FROM cases
          CROSS JOIN UNNEST(cases.hospitalizations) AS hospitalization
        )
        SELECT
          tenants.uuid,
          date::date,
          COUNT(DISTINCT cases_with_hospitalizations.person_uuid) AS count
        FROM GENERATE_SERIES(
          LEAST((SELECT MIN(inserted_at::date) from cases), CURRENT_DATE - INTERVAL '1 year'),
          CURRENT_DATE,
          interval '1 day'
        ) AS date
        CROSS JOIN tenants
        LEFT JOIN cases_with_hospitalizations
          ON (
            tenants.uuid = cases_with_hospitalizations.tenant_uuid AND
            cases_with_hospitalizations.end_date >= date AND
            cases_with_hospitalizations.start_date <= date
          )
        GROUP BY date, tenants.uuid
        ORDER BY date, tenants.uuid
    """)

    create unique_index(:statistics_active_hospitalization_cases_per_day, [:tenant_uuid, :date])
    create index(:statistics_active_hospitalization_cases_per_day, [:tenant_uuid])
    create index(:statistics_active_hospitalization_cases_per_day, [:date])
  end
end
