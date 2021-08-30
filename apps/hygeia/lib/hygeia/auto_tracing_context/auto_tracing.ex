defmodule Hygeia.AutoTracingContext.AutoTracing do
  @moduledoc """
  Auto Tracing Model
  """

  use Hygeia, :model

  alias Hygeia.AutoTracingContext.AutoTracing.Occupation
  alias Hygeia.AutoTracingContext.AutoTracing.Problem
  alias Hygeia.AutoTracingContext.AutoTracing.Step
  alias Hygeia.AutoTracingContext.AutoTracing.Transmission
  alias Hygeia.CaseContext.Case

  @type empty :: %__MODULE__{
          uuid: Ecto.UUID.t() | nil,
          current_step: Step.t() | nil,
          last_completed_step: Step.t() | nil,
          employed: boolean() | nil,
          occupations: [Occupation.t()] | nil,
          transmission: Transmission.t() | nil,
          problems: [Problem.t()] | nil,
          solved_problems: [Problem.t()] | nil,
          unsolved_problems: boolean() | nil,
          covid_app: boolean() | nil,
          case: Ecto.Schema.belongs_to(Case.t()) | nil,
          case_uuid: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type t :: %__MODULE__{
          uuid: Ecto.UUID.t(),
          current_step: Step.t(),
          last_completed_step: Step.t(),
          employed: boolean() | nil,
          occupations: [Occupation.t()] | nil,
          transmission: Transmission.t() | nil,
          problems: [Problem.t()],
          solved_problems: [Problem.t()],
          unsolved_problems: boolean(),
          covid_app: boolean() | nil,
          case: Ecto.Schema.belongs_to(Case.t()),
          case_uuid: Ecto.UUID.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Phoenix.Param, key: :uuid}

  schema "auto_tracings" do
    field :current_step, Step, default: :start
    field :last_completed_step, Step, default: :start
    field :covid_app, :boolean
    field :employed, :boolean
    field :problems, {:array, Problem}, default: []
    field :solved_problems, {:array, Problem}, default: []
    field :unsolved_problems, :boolean, default: false

    embeds_many :occupations, Occupation, on_replace: :delete

    embeds_one :transmission, Transmission, on_replace: :update

    belongs_to :case, Case, references: :uuid, foreign_key: :case_uuid

    timestamps()
  end

  @spec changeset(
          auto_tracing :: t | empty | Changeset.t(t | empty),
          attrs :: Hygeia.ecto_changeset_params()
        ) ::
          Changeset.t()
  def changeset(auto_tracing, attrs \\ %{}) do
    auto_tracing
    |> cast(attrs, [
      :current_step,
      :last_completed_step,
      :case_uuid,
      :covid_app,
      :employed,
      :problems,
      :solved_problems
    ])
    |> validate_required([:current_step, :last_completed_step, :case_uuid])
    |> cast_embed(:occupations)
    |> cast_embed(:transmission)
    |> set_unsolved_problems()
  end

  defp set_unsolved_problems(changeset) do
    problems = MapSet.new(get_field(changeset, :problems, []))
    solved_problems = MapSet.new(get_field(changeset, :solved_problems, []))

    put_change(changeset, :unsolved_problems, not MapSet.equal?(problems, solved_problems))
  end

  @spec has_problem?(t, problem :: Problem.t()) :: boolean
  def has_problem?(%__MODULE__{problems: problems}, problem), do: problem in problems

  @spec unsolved_problems(t) :: [Problem.t()]
  def unsolved_problems(%__MODULE__{problems: problems, solved_problems: solved_problems}) do
    problems = MapSet.new(problems)
    solved_problems = MapSet.new(solved_problems)

    problems
    |> MapSet.difference(solved_problems)
    |> MapSet.to_list()
  end

  @spec step_available?(auto_tracing :: t, step :: Step.t()) :: boolean()
  def step_available?(%__MODULE__{} = auto_tracing, step) do
    steps = Step.__enum_map__()

    step_index = Enum.find_index(steps, &(&1 == step))

    if has_problem?(auto_tracing, :unmanaged_tenant) do
      step_index <= Enum.find_index(steps, &(&1 == :address))
    else
      step_index <= Enum.find_index(steps, &(&1 == auto_tracing.last_completed_step)) + 1
    end
  end

  @spec step_completed?(auto_tracing :: t, step :: Step.t()) :: boolean()
  def step_completed?(auto_tracing, step) do
    steps = Step.__enum_map__()

    Enum.find_index(steps, &(&1 == step)) <=
      Enum.find_index(steps, &(&1 == auto_tracing.last_completed_step))
  end

  @spec first_not_completed_step?(auto_tracing :: t, step :: Step.t()) ::
          boolean()
  def first_not_completed_step?(auto_tracing, step),
    do: Step.get_next_step(auto_tracing.last_completed_step) == step

  defimpl Hygeia.Authorization.Resource do
    alias Hygeia.Authorization.Resource
    alias Hygeia.AutoTracingContext.AutoTracing
    alias Hygeia.CaseContext.Person
    alias Hygeia.Repo
    alias Hygeia.UserContext.User

    @spec preload(resource :: AutoTracing.t()) :: AutoTracing.t()
    def preload(resource), do: Repo.preload(resource, case: [tenant: []])

    @spec authorized?(
            resource :: AutoTracing.t(),
            action :: :create | :details | :list | :update | :delete | :accept,
            user :: :anonymous | User.t() | Person.t(),
            meta :: %{atom() => term}
          ) :: boolean
    def authorized?(_auto_tracing, :create, %User{} = user, %{case: case} = meta),
      do: Resource.authorized?(case, :update, user, meta)

    def authorized?(_auto_tracing, :list, %User{} = user, %{case: case} = meta),
      do: Resource.authorized?(case, :details, user, meta)

    def authorized?(%AutoTracing{case: case}, :details, %User{} = user, meta),
      do: Resource.authorized?(case, :details, user, meta)

    def authorized?(%AutoTracing{case: case}, action, %User{} = user, meta)
        when action in [:update, :delete, :accept, :resolve_problems],
        do: Resource.authorized?(case, :update, user, meta)

    def authorized?(_auto_tracing, action, %Person{uuid: person_uuid}, %{
          case: %Case{person_uuid: person_uuid}
        })
        when action in [:create, :list],
        do: true

    def authorized?(
          %AutoTracing{case: %Case{person_uuid: person_uuid}},
          action,
          %Person{uuid: person_uuid},
          _meta
        )
        when action in [:details, :update, :delete],
        do: true

    def authorized?(_auto_tracing, action, _user, _meta)
        when action in [:create, :details, :list, :update, :delete, :accept, :resolve_problems],
        do: false
  end
end