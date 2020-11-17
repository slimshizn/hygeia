defmodule Hygeia.CaseContext.Case.Clinical do
  @moduledoc """
  Model for Clinical Schema
  """

  use Hygeia, :model

  import EctoEnum

  defenum TestReason, :test_reason, [
    "symptoms",
    "outbreak_examination",
    "screening",
    "work_related",
    "quarantine",
    "app_report",
    "contact_tracing"
  ]

  defenum Symptom, :symptom, ["fever", "cough", "loss_of_smell", "loss_of_taste"]

  defenum TestKind, :test_kind, ["pcr", "serology", "quick"]

  defenum Result, :test_result, ["positive", "negative"]

  @type empty :: %__MODULE__{
          reasons_for_test: [TestReason.t()] | nil,
          symptoms: [Symptom.t()] | nil,
          symptom_start: Date.t() | nil,
          test: Date.t() | nil,
          laboratory_report: Date.t() | nil,
          test_kind: TestKind.t() | nil,
          result: Result.t() | nil
        }

  @type t :: %__MODULE__{
          reasons_for_test: [TestReason.t()],
          symptoms: [Symptom.t()],
          symptom_start: Date.t() | nil,
          test: Date.t() | nil,
          laboratory_report: Date.t() | nil,
          test_kind: TestKind.t() | nil,
          result: Result.t() | nil
        }

  embedded_schema do
    field :reasons_for_test, {:array, TestReason}
    field :symptoms, {:array, Symptom}
    field :symptom_start, :date
    field :test, :date
    field :laboratory_report, :date
    field :test_kind, TestKind
    field :result, Result
  end

  @doc false
  @spec changeset(clinical :: t | empty, attrs :: Hygeia.ecto_changeset_params()) :: Changeset.t()
  def changeset(clinical, attrs) do
    clinical
    |> cast(attrs, [
      :reasons_for_test,
      :symptoms,
      :symptom_start,
      :test,
      :laboratory_report,
      :test_kind,
      :result
    ])
    |> validate_required([])
  end
end
