defmodule Hygeia.CaseContext.Test do
  @moduledoc """
  test Model
  """
  use Hygeia, :model

  alias Hygeia.CaseContext.Case
  alias Hygeia.CaseContext.Entity
  alias Hygeia.CaseContext.Test.Kind
  alias Hygeia.CaseContext.Test.Result
  alias Hygeia.MutationContext.Mutation

  @type empty :: %__MODULE__{
          uuid: Ecto.UUID.t() | nil,
          kind: Kind.t() | nil,
          laboratory_reported_at: Date.t() | nil,
          reporting_unit: Entity.t() | nil,
          result: Result.t() | nil,
          sponsor: Entity.t() | nil,
          tested_at: Date.t() | nil,
          case: Ecto.Schema.belongs_to(Case.t()) | nil,
          reference: String.t() | nil,
          mutation_uuid: Ecto.UUID.t() | nil,
          mutation: Ecto.Schema.belongs_to(Mutation.t()) | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @type t :: %__MODULE__{
          uuid: Ecto.UUID.t(),
          kind: Kind.t(),
          laboratory_reported_at: Date.t() | nil,
          reporting_unit: Entity.t() | nil,
          result: Result.t() | nil,
          sponsor: Entity.t() | nil,
          tested_at: Date.t() | nil,
          case: Ecto.Schema.belongs_to(Case.t()),
          reference: String.t() | nil,
          mutation_uuid: Ecto.UUID.t() | nil,
          mutation: Ecto.Schema.belongs_to(Mutation.t()) | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Phoenix.Param, key: :uuid}

  schema "tests" do
    field :kind, Kind
    field :laboratory_reported_at, :date
    field :result, Result
    field :tested_at, :date
    field :reference, :string

    embeds_one :sponsor, Entity, on_replace: :update
    embeds_one :reporting_unit, Entity, on_replace: :update

    belongs_to :case, Case, references: :uuid, foreign_key: :case_uuid
    belongs_to :mutation, Mutation, references: :uuid, foreign_key: :mutation_uuid

    timestamps()
  end

  @doc false
  @spec changeset(
          test :: t | empty | Changeset.t(t | empty),
          attrs :: Hygeia.ecto_changeset_params()
        ) :: Changeset.t(t)
  def changeset(test, attrs) do
    test
    |> cast(attrs, [
      :uuid,
      :tested_at,
      :laboratory_reported_at,
      :kind,
      :result,
      :reference,
      :mutation_uuid
    ])
    |> fill_uuid()
    |> validate_required([:kind])
    |> cast_embed(:sponsor)
    |> cast_embed(:reporting_unit)
  end
end