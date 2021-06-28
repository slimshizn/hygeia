# credo:disable-for-this-file Credo.Check.Readability.ModuleNames
defmodule Hygeia.ImportContext.Planner.Generator.ISM_2021_06_11 do
  @moduledoc false

  alias Hygeia.CaseContext
  alias Hygeia.CaseContext.Case
  alias Hygeia.CaseContext.Case.Phase
  alias Hygeia.CaseContext.Person
  alias Hygeia.CaseContext.Person.ContactMethod
  alias Hygeia.CaseContext.Test
  alias Hygeia.ImportContext.Planner
  alias Hygeia.ImportContext.Row
  alias Hygeia.Repo
  alias Hygeia.TenantContext.Tenant

  @type field_mapping :: %{required(atom) => String.t()}

  @origin_country Application.compile_env!(:hygeia, [:phone_number_parsing_origin_country])

  @external_reference_mapping [
    {:case, :ism_case, :case_id},
    {:case, :ism_report, :report_id},
    {:person, :ism_patient, :patient_id}
  ]

  @person_field_path %{
    last_name: [:last_name],
    first_name: [:first_name],
    birth_date: [:birth_date],
    sex: [:sex],
    phone: [:phone],
    address: [:address, :address],
    zip: [:address, :zip],
    place: [:address, :place],
    subdivision: [:address, :subdivision],
    country: [:address, :country]
  }

  @test_field_path %{
    tested_at: [:tested_at],
    laboratory_reported_at: [:laboratory_reported_at],
    test_result: [:result],
    test_kind: [:kind],
    test_reference: [:reference],
    reporting_unit_name: [:reporting_unit, :name],
    reporting_unit_division: [:reporting_unit, :division],
    reporting_unit_person_first_name: [:reporting_unit, :person_first_name],
    reporting_unit_person_last_name: [:reporting_unit, :person_last_name],
    reporting_unit_address: [:reporting_unit, :address, :address],
    reporting_unit_zip: [:reporting_unit, :address, :zip],
    reporting_unit_place: [:reporting_unit, :address, :place],
    sponsor_name: [:sponsor, :name],
    sponsor_division: [:sponsor, :division],
    sponsor_person_first_name: [:sponsor, :person_first_name],
    sponsor_person_last_name: [:sponsor, :person_last_name],
    sponsor_address: [:sponsor, :address, :address],
    sponsor_zip: [:sponsor, :address, :zip],
    sponsor_place: [:sponsor, :address, :place],
    mutation_ism_code: [:mutation, :ism_code]
  }

  @spec select_tenant(field_mapping :: field_mapping) ::
          (row :: Row.t(),
           params :: Planner.Generator.params(),
           preceeding_action_plan :: [Planner.Action.t()] ->
             {Planner.certainty(), Planner.Action.t()})
  def select_tenant(field_mapping) do
    fn %Row{tenant: row_tenant}, %{data: data, tenants: tenants} = _params, _preceeding_steps ->
      {certainty, tenant} =
        with short_name when is_binary(short_name) <-
               Row.get_change_field(data, [field_mapping.tenant_short_name]),
             %Tenant{} = tenant <-
               Enum.find(tenants, &match?(%Tenant{short_name: ^short_name}, &1)) do
          {:certain, tenant}
        else
          nil -> {:uncertain, row_tenant}
        end

      {certainty, %Planner.Action.ChooseTenant{tenant: tenant}}
    end
  end

  @spec select_case(field_mapping :: field_mapping) ::
          (row :: Row.t(),
           params :: Planner.Generator.params(),
           preceeding_action_plan :: [Planner.Action.t()] ->
             {Planner.certainty(), Planner.Action.t()})
  def select_case(field_mapping) do
    fn
      _row, %{predecessor: %Row{case: %Case{} = case}}, _preceeding_steps ->
        case = Repo.preload(case, person: [], tenant: [], tests: [])
        {:certain, %Planner.Action.SelectCase{case: case, person: case.person}}

      _row, %{changes: changes}, _preceeding_steps ->
        Enum.reduce_while(
          [
            fn ->
              find_case_by_external_reference(
                :ism_case,
                Row.get_change_field(changes, [field_mapping.case_id])
              )
            end,
            fn ->
              find_case_by_external_reference(
                :ism_report,
                Row.get_change_field(changes, [field_mapping.report_id])
              )
            end,
            fn ->
              find_person_by_external_reference(
                :ism_patient,
                Row.get_change_field(changes, [field_mapping.patient_id])
              )
            end,
            fn ->
              find_person_by_name(
                Row.get_change_field(changes, [field_mapping.first_name]),
                Row.get_change_field(changes, [field_mapping.last_name]),
                changes,
                field_mapping
              )
            end,
            fn -> find_person_by_phone(Row.get_change_field(changes, [field_mapping.phone])) end,
            fn -> find_person_by_email(Row.get_change_field(changes, [field_mapping[:email]])) end
          ],
          {:certain, %Planner.Action.SelectCase{}},
          fn search_fn, acc ->
            case search_fn.() do
              {:ok, {certainty, action}} -> {:halt, {certainty, action}}
              :error -> {:cont, acc}
            end
          end
        )
    end
  end

  defp find_case_by_external_reference(type, id)
  defp find_case_by_external_reference(_type, ""), do: :error
  defp find_case_by_external_reference(_type, nil), do: :error

  defp find_case_by_external_reference(type, id) do
    with [case | _] <- CaseContext.list_cases_by_external_reference(type, to_string(id)),
         case <- Repo.preload(case, person: [], tenant: [], tests: []) do
      {:ok, {:certain, %Planner.Action.SelectCase{case: case, person: case.person}}}
    else
      [] -> :error
    end
  end

  defp find_person_by_external_reference(type, id)
  defp find_person_by_external_reference(_type, ""), do: :error
  defp find_person_by_external_reference(_type, nil), do: :error

  defp find_person_by_external_reference(type, id) do
    with [person | _] <- CaseContext.list_people_by_external_reference(type, to_string(id)),
         person <- Repo.preload(person, cases: [tenant: [], tests: []]) do
      {:ok, select_active_cases(person)}
    else
      [] -> :error
    end
  end

  defp find_person_by_name(first_name, last_name, changes, field_mapping)
  defp find_person_by_name(nil, _last_name, _changes, _field_mapping), do: :error
  defp find_person_by_name("", _last_name, _changes, _field_mapping), do: :error
  defp find_person_by_name(_first_name, nil, _changes, _field_mapping), do: :error
  defp find_person_by_name(_first_name, "", _changes, _field_mapping), do: :error

  defp find_person_by_name(first_name, last_name, changes, field_mapping) do
    first_name
    |> CaseContext.list_people_by_name(last_name)
    |> Repo.preload(cases: [person: [], tenant: [], tests: []])
    |> Enum.map(
      &{person_phone_matches?(&1, Row.get_change_field(changes, [field_mapping.phone])), &1}
    )
    |> Enum.sort()
    |> case do
      [] -> :error
      [{true, person}] -> {:ok, select_active_cases(person)}
      [{false, person}] -> {:ok, select_active_cases(person, :input_needed)}
      [{_phone_matches, person} | _others] -> {:ok, select_active_cases(person)}
    end
  end

  defp find_person_by_phone(phone)
  defp find_person_by_phone(nil), do: :error
  defp find_person_by_phone(""), do: :error

  defp find_person_by_phone(phone) do
    [
      CaseContext.list_people_by_contact_method(:mobile, phone),
      CaseContext.list_people_by_contact_method(:landline, phone)
    ]
    |> List.flatten()
    |> Enum.uniq_by(& &1.uuid)
    |> Repo.preload(cases: [person: [], tenant: [], tests: []])
    |> case do
      [] -> :error
      [person | _others] -> {:ok, select_active_cases(person, :input_needed)}
    end
  end

  defp find_person_by_email(email)
  defp find_person_by_email(nil), do: :error
  defp find_person_by_email(""), do: :error

  defp find_person_by_email(email) do
    :email
    |> CaseContext.list_people_by_contact_method(email)
    |> Repo.preload(cases: [person: [], tenant: [], tests: []])
    |> case do
      [] -> :error
      [person | _others] -> {:ok, select_active_cases(person, :input_needed)}
    end
  end

  defp select_active_cases(%Person{cases: cases} = person, max_certainty \\ :certain) do
    was_index =
      cases != [] and
        Enum.any?(cases, fn case ->
          Enum.any?(case.phases, &match?(%Phase{details: %Phase.Index{}}, &1))
        end)

    cases
    |> Enum.filter(fn %Case{inserted_at: inserted_at, phases: phases} ->
      phase_active =
        phases
        |> Enum.filter(& &1.quarantine_order)
        |> Enum.map(&Date.range(&1.start, &1.end))
        |> Enum.any?(&Enum.member?(&1, Date.utc_today()))

      case_recent = abs(Date.diff(DateTime.to_date(inserted_at), Date.utc_today())) < 10

      phase_active or case_recent
    end)
    |> case do
      [] when was_index ->
        {:input_needed,
         %Planner.Action.SelectCase{case: nil, person: person, suppress_quarantine: true}}

      [] ->
        {max_certainty, %Planner.Action.SelectCase{case: nil, person: person}}

      [case] ->
        {max_certainty, %Planner.Action.SelectCase{case: case, person: person}}

      [case, _other_case | _rest] ->
        {Planner.limit_certainty(:uncertain, max_certainty),
         %Planner.Action.SelectCase{case: case, person: person}}
    end
  end

  defp person_phone_matches?(person, phone)
  defp person_phone_matches?(_person, nil), do: false
  defp person_phone_matches?(_person, ""), do: false

  defp person_phone_matches?(%Person{contact_methods: contact_methods}, phone) do
    with {:ok, parsed_number} <- ExPhoneNumber.parse(phone, @origin_country),
         formatted_phone <- ExPhoneNumber.Formatting.format(parsed_number, :international) do
      Enum.any?(contact_methods, &match?(%ContactMethod{value: ^formatted_phone}, &1))
    else
      {:error, _reason} -> false
    end
  end

  @spec save(
          row :: Row.t(),
          params :: Planner.Generator.params(),
          preceeding_action_plan :: [Planner.Action.t()]
        ) ::
          {Planner.certainty(), Planner.Action.t()}
  def save(_row, _params, _preceeding_steps), do: {:certain, %Planner.Action.Save{}}

  @spec patch_phase(
          row :: Row.t(),
          params :: Planner.Generator.params(),
          preceeding_action_plan :: [Planner.Action.t()]
        ) ::
          {Planner.certainty(), Planner.Action.t()}
  def patch_phase(_row, _params, preceeding_steps) do
    {:certain,
     case Enum.find(preceeding_steps, &match?({_certainty, %Planner.Action.SelectCase{}}, &1)) do
       {_certainty, %Planner.Action.SelectCase{case: nil, suppress_quarantine: true}} ->
         %Planner.Action.PatchPhases{action: :append, phase_type: :index, quarantine_order: false}

       {_certainty, %Planner.Action.SelectCase{case: nil}} ->
         %Planner.Action.PatchPhases{action: :append, phase_type: :index}

       {_certainty,
        %Planner.Action.SelectCase{
          case: %Case{phases: phases},
          suppress_quarantine: suppress_quarantine
        }} ->
         if Enum.any?(phases, &match?(%Case.Phase{details: %Case.Phase.Index{}}, &1)) do
           %Planner.Action.PatchPhases{action: :skip, phase_type: :index}
         else
           if suppress_quarantine do
             %Planner.Action.PatchPhases{
               action: :append,
               phase_type: :index,
               quarantine_order: false
             }
           else
             %Planner.Action.PatchPhases{action: :append, phase_type: :index}
           end
         end
     end}
  end

  @spec patch_extenal_references(field_mapping :: field_mapping) ::
          (row :: Row.t(),
           params :: Planner.Generator.params(),
           preceeding_action_plan :: [Planner.Action.t()] ->
             {Planner.certainty(), Planner.Action.t()})
  def patch_extenal_references(field_mapping) do
    fn _row, %{changes: changes}, _preceeding_steps ->
      external_references =
        @external_reference_mapping
        |> Enum.map(fn {subject, type, common_field_identifier} ->
          {subject, type, Row.get_change_field(changes, [field_mapping[common_field_identifier]])}
        end)
        |> Enum.reject(&match?({_subject, _type, nil}, &1))

      {:certain, %Planner.Action.PatchExternalReferences{references: external_references}}
    end
  end

  @spec patch_person(field_mapping :: field_mapping) ::
          (row :: Row.t(),
           params :: Planner.Generator.params(),
           preceeding_action_plan :: [Planner.Action.t()] ->
             {Planner.certainty(), Planner.Action.t()})
  def patch_person(field_mapping) do
    fn _row, %{changes: changes}, _preceeding_steps ->
      {:certain,
       %Planner.Action.PatchPerson{
         person_attrs:
           @person_field_path
           |> Enum.map(fn {common_field_identifier, destination_path} ->
             {field_mapping[common_field_identifier], destination_path}
           end)
           |> Enum.map(fn {field_name, destination_path} ->
             {destination_path, Row.get_change_field(changes, [field_name])}
           end)
           |> Enum.reject(&match?({_path, nil}, &1))
           |> Enum.map(&normalize_person_data/1)
           |> extract_field_changes()
       }}
    end
  end

  @spec normalize_person_data({path :: [atom], value :: term}) ::
          {path :: [atom], value :: term}
  defp normalize_person_data(field)

  defp normalize_person_data({[:sex] = path, sex}) when is_binary(sex) do
    {path,
     cond do
       String.downcase(sex) == String.downcase("männlich") -> :male
       String.downcase(sex) == String.downcase("weiblich") -> :female
       String.downcase(sex) == String.downcase("anders") -> :other
       true -> nil
     end}
  end

  defp normalize_person_data({[:patient_id], value}) do
    [{[:external_references, 0, :type], :ism_patient}, {[:external_references, 0, :value], value}]
  end

  defp normalize_person_data({[:birth_date] = path, date}) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, date} -> {path, date}
      {:error, _reason} -> {path, nil}
    end
  end

  defp normalize_person_data({[:phone] = path, value}) when is_binary(value) do
    with {:ok, parsed_number} <-
           ExPhoneNumber.parse(value, @origin_country),
         true <- ExPhoneNumber.is_valid_number?(parsed_number),
         phone_number_type when phone_number_type in [:fixed_line, :voip] <-
           ExPhoneNumber.Validation.get_number_type(parsed_number) do
      [{[:contact_methods, 0, :type], :landline}, {[:contact_methods, 0, :value], value}]
    else
      {:error, _reason} -> {path, nil}
      false -> {path, nil}
      _other -> [{[:contact_methods, 0, :type], :mobile}, {[:contact_methods, 0, :value], value}]
    end
  end

  defp normalize_person_data({path, country} = field) when is_binary(country) do
    with :country <- List.last(path),
         locale = HygeiaCldr.get_locale().language,
         upcase_country = String.upcase(country),
         downcase_country = String.downcase(country),
         country_ids = Cadastre.Country.ids(),
         false <- upcase_country in country_ids,
         %{^downcase_country => code} <-
           Map.new(
             country_ids,
             &{&1 |> Cadastre.Country.new() |> Cadastre.Country.name(locale) |> String.downcase(),
              &1}
           ) do
      {path, code}
    else
      field_name when is_atom(field_name) -> field
      true -> field
      %{} -> {path, nil}
    end
  end

  defp normalize_person_data({path, value}) do
    if List.last(path) == :zip do
      {path, to_string(value)}
    else
      {path, value}
    end
  end

  @spec extract_field_changes(field :: [field | [field]]) :: map
        when field: {path :: [atom], value :: term}
  def extract_field_changes(fields) do
    fields
    |> List.flatten()
    |> Enum.reject(&match?({_path, nil}, &1))
    |> Enum.map(fn {path, value} ->
      {Enum.map(path, &Access.key(&1, %{})), value}
    end)
    |> Enum.reduce(%{}, fn {path, value}, acc ->
      put_in(acc, path, value)
    end)
  end

  @spec patch_tests(field_mapping :: field_mapping) ::
          (row :: Row.t(),
           params :: Planner.Generator.params(),
           preceeding_action_plan :: [Planner.Action.t()] ->
             {Planner.certainty(), Planner.Action.t()})
  def patch_tests(field_mapping) do
    fn row, %{changes: changes}, preceeding_steps ->
      test_attrs =
        @test_field_path
        |> Enum.map(fn {common_field_identifier, destination_path} ->
          {field_mapping[common_field_identifier], destination_path}
        end)
        |> Enum.map(fn {field_name, destination_path} ->
          {destination_path, Row.get_change_field(changes, [field_name])}
        end)
        |> Enum.reject(&match?({_path, nil}, &1))
        |> Enum.map(&normalize_test_data/1)
        |> extract_field_changes()

      reference = Row.get_data_field(row, [field_mapping[:test_reference]])

      action =
        case Enum.find(preceeding_steps, &match?({_certainty, %Planner.Action.SelectCase{}}, &1)) do
          {_certainty, %Planner.Action.SelectCase{case: nil}} ->
            :append

          {_certainty, %Planner.Action.SelectCase{case: %Case{tests: tests}}} ->
            if Enum.any?(tests, &match?(%Test{reference: ^reference}, &1)),
              do: :patch,
              else: :append
        end

      {:certain,
       %Planner.Action.PatchTests{reference: reference, action: action, test_attrs: test_attrs}}
    end
  end

  @spec normalize_test_data({path :: [atom], value :: term}) ::
          {path :: [atom], value :: term}
  defp normalize_test_data(field)

  defp normalize_test_data({[:result] = path, result}) when is_binary(result) do
    {path,
     cond do
       String.downcase(result) == "positiv" -> :positive
       String.downcase(result) == "negativ" -> :negative
       String.downcase(result) == "nicht bestimmbar" -> :inconclusive
       true -> nil
     end}
  end

  defp normalize_test_data({[:kind] = path, kind}) when is_binary(kind) do
    {path,
     cond do
       String.downcase(kind) == String.downcase("Antigen ++ Schnelltest") -> :antigen_quick
       String.downcase(kind) == String.downcase("Nukleinsäure ++ PCR") -> :pcr
       String.downcase(kind) == String.downcase("PCR") -> :pcr
       String.downcase(kind) == String.downcase("Serologie") -> :serology
       true -> nil
     end}
  end

  defp normalize_test_data({path, date})
       when is_binary(date) and path in [[:tested_at], [:laboratory_reported_at]] do
    case Date.from_iso8601(date) do
      {:ok, date} -> {path, date}
      {:error, _reason} -> {path, nil}
    end
  end

  defp normalize_test_data({path, value}) do
    if List.last(path) == :zip do
      {path, to_string(value)}
    else
      {path, value}
    end
  end

  @spec patch_assignee(
          row :: Row.t(),
          params :: Planner.Generator.params(),
          preceeding_action_plan :: [Planner.Action.t()]
        ) ::
          {Planner.certainty(), Planner.Action.t()}
  def patch_assignee(_row, _params, preceeding_steps) do
    {:certain,
     case Enum.find(preceeding_steps, &match?({_certainty, %Planner.Action.PatchPhases{}}, &1)) do
       {_certainty, %Planner.Action.PatchPhases{action: :skip}} ->
         %Planner.Action.PatchAssignee{action: :skip}

       {_certainty, %Planner.Action.PatchPhases{action: :append}} ->
         %Planner.Action.PatchAssignee{action: :change, tracer_uuid: nil, supervisor_uuid: nil}
     end}
  end

  @spec patch_status(
          row :: Row.t(),
          params :: Planner.Generator.params(),
          preceeding_action_plan :: [Planner.Action.t()]
        ) ::
          {Planner.certainty(), Planner.Action.t()}
  def patch_status(_row, _params, preceeding_steps) do
    {:certain,
     case Enum.find(preceeding_steps, &match?({_certainty, %Planner.Action.PatchPhases{}}, &1)) do
       {_certainty, %Planner.Action.PatchPhases{action: :skip}} ->
         %Planner.Action.PatchStatus{action: :skip}

       {_certainty, %Planner.Action.PatchPhases{action: :append}} ->
         if Enum.find(
              preceeding_steps,
              &match?({_certainty, %Planner.Action.SelectCase{suppress_quarantine: true}}, &1)
            ) do
           %Planner.Action.PatchStatus{action: :change, status: :done}
         else
           %Planner.Action.PatchStatus{action: :change, status: :first_contact}
         end
     end}
  end
end