defmodule Hygeia.CaseContextTest do
  @moduledoc false

  use Hygeia.DataCase

  import Mox

  alias Hygeia.CaseContext
  alias Hygeia.CaseContext.Address
  alias Hygeia.CaseContext.Clinical
  alias Hygeia.CaseContext.ContactMethod
  alias Hygeia.CaseContext.Employer
  alias Hygeia.CaseContext.ExternalReference
  alias Hygeia.CaseContext.Hospitalization
  alias Hygeia.CaseContext.Monitoring
  alias Hygeia.CaseContext.Note
  alias Hygeia.CaseContext.Person
  alias Hygeia.CaseContext.Phase
  alias Hygeia.CaseContext.Profession
  alias Hygeia.CaseContext.ProtocolEntry
  alias Hygeia.CaseContext.Sms
  alias Hygeia.OrganisationContext.Organisation
  alias Hygeia.TenantContext.Tenant
  alias Hygeia.UserContext.User

  @moduletag origin: :test
  @moduletag originator: :noone

  describe "professions" do
    @valid_attrs %{name: "some name"}
    @update_attrs %{name: "some updated name"}
    @invalid_attrs %{name: nil}

    test "list_professions/0 returns all professions" do
      profession = profession_fixture()
      assert CaseContext.list_professions() == [profession]
    end

    test "get_profession!/1 returns the profession with given id" do
      profession = profession_fixture()
      assert CaseContext.get_profession!(profession.uuid) == profession
    end

    test "create_profession/1 with valid data creates a profession" do
      assert {:ok, %Profession{} = profession} = CaseContext.create_profession(@valid_attrs)
      assert profession.name == "some name"
    end

    test "create_profession/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = CaseContext.create_profession(@invalid_attrs)
    end

    test "update_profession/2 with valid data updates the profession" do
      profession = profession_fixture()

      assert {:ok, %Profession{} = profession} =
               CaseContext.update_profession(profession, @update_attrs)

      assert profession.name == "some updated name"
    end

    test "update_profession/2 with invalid data returns error changeset" do
      profession = profession_fixture()

      assert {:error, %Ecto.Changeset{}} =
               CaseContext.update_profession(profession, @invalid_attrs)

      assert profession == CaseContext.get_profession!(profession.uuid)
    end

    test "delete_profession/1 deletes the profession" do
      profession = profession_fixture()
      assert {:ok, %Profession{}} = CaseContext.delete_profession(profession)
      assert_raise Ecto.NoResultsError, fn -> CaseContext.get_profession!(profession.uuid) end
    end

    test "change_profession/1 returns a profession changeset" do
      profession = profession_fixture()
      assert %Ecto.Changeset{} = CaseContext.change_profession(profession)
    end
  end

  describe "people" do
    alias Hygeia.CaseContext.Person

    @valid_attrs %{
      address: %{
        address: "Neugasse 51",
        zip: "9000",
        place: "St. Gallen",
        subdivision: "SG",
        country: "CH"
      },
      birth_date: ~D[2010-04-17],
      contact_methods: [
        %{
          type: :mobile,
          value: "+41 78 724 57 90",
          comment: "Call only between 7 and 9 am"
        }
      ],
      employers: [
        %{
          name: "JOSHMARTIN GmbH",
          address: %{
            address: "Neugasse 51",
            zip: "9000",
            place: "St. Gallen",
            subdivision: "SG",
            country: "CH"
          }
        }
      ],
      external_references: [],
      first_name: "some first_name",
      last_name: "some last_name",
      sex: :female
    }
    @update_attrs %{
      birth_date: ~D[2011-05-18],
      first_name: "some updated first_name",
      last_name: "some updated last_name",
      sex: :male
    }
    @invalid_attrs %{
      address: nil,
      birth_date: nil,
      contact_methods: nil,
      employers: nil,
      external_references: nil,
      first_name: nil,
      last_name: nil,
      sex: nil
    }

    test "list_people/0 returns all people" do
      person = person_fixture()
      assert CaseContext.list_people() == [person]
    end

    test "get_person!/1 returns the person with given id" do
      person = person_fixture()
      assert CaseContext.get_person!(person.uuid) == person
    end

    test "create_person/1 with valid data creates a person" do
      tenant = tenant_fixture()

      assert {:ok,
              %Person{
                address: %Address{
                  address: "Neugasse 51",
                  zip: "9000",
                  place: "St. Gallen",
                  subdivision: "SG",
                  country: "CH"
                },
                birth_date: ~D[2010-04-17],
                contact_methods: [
                  %ContactMethod{
                    type: :mobile,
                    value: "+41787245790",
                    comment: "Call only between 7 and 9 am"
                  }
                ],
                employers: [
                  %Employer{
                    name: "JOSHMARTIN GmbH",
                    address: %Address{
                      address: "Neugasse 51",
                      zip: "9000",
                      place: "St. Gallen",
                      subdivision: "SG",
                      country: "CH"
                    }
                  }
                ],
                external_references: [],
                first_name: "some first_name",
                human_readable_id: _,
                last_name: "some last_name",
                sex: :female
              }} = CaseContext.create_person(tenant, @valid_attrs)
    end

    test "create_person/1 with valid data formats phone number" do
      tenant = tenant_fixture()

      assert {:ok,
              %Person{
                contact_methods: [
                  %ContactMethod{
                    type: :mobile,
                    value: "+41787245790"
                  },
                  %ContactMethod{
                    type: :mobile,
                    value: "+41787245790"
                  },
                  %ContactMethod{
                    type: :landline,
                    value: "+41715117254"
                  },
                  %ContactMethod{
                    type: :email,
                    value: "example@example.com"
                  }
                ]
              }} =
               CaseContext.create_person(tenant, %{
                 contact_methods: [
                   %{
                     type: :mobile,
                     value: "+41 78 724 57 90"
                   },
                   %{
                     type: :mobile,
                     value: "078 724 57 90"
                   },
                   %{
                     type: :landline,
                     value: "0041715117254"
                   },
                   %{
                     type: :email,
                     value: "example@example.com"
                   }
                 ],
                 first_name: "some first_name",
                 last_name: "some last_name"
               })
    end

    test "create_person/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               CaseContext.create_person(tenant_fixture(), @invalid_attrs)
    end

    test "update_person/2 with valid data updates the person" do
      person = person_fixture()

      assert {:ok,
              %Person{
                address: %Address{
                  address: "Neugasse 51",
                  zip: "9000",
                  place: "St. Gallen",
                  subdivision: "SG",
                  country: "CH"
                },
                birth_date: ~D[2011-05-18],
                contact_methods: [
                  %ContactMethod{
                    type: :mobile,
                    value: "+41787245790",
                    comment: "Call only between 7 and 9 am"
                  }
                ],
                employers: [
                  %Employer{
                    name: "JOSHMARTIN GmbH",
                    address: %Address{
                      address: "Neugasse 51",
                      zip: "9000",
                      place: "St. Gallen",
                      subdivision: "SG",
                      country: "CH"
                    }
                  }
                ],
                external_references: [
                  %Hygeia.CaseContext.ExternalReference{
                    type: :ism,
                    type_name: nil,
                    uuid: _,
                    value: "7000"
                  },
                  %Hygeia.CaseContext.ExternalReference{
                    type: :other,
                    type_name: "foo",
                    uuid: _,
                    value: "7000"
                  }
                ],
                first_name: "some updated first_name",
                human_readable_id: _,
                last_name: "some updated last_name",
                sex: :male
              }} = CaseContext.update_person(person, @update_attrs)
    end

    test "update_person/2 with invalid data returns error changeset" do
      person = person_fixture()
      assert {:error, %Ecto.Changeset{}} = CaseContext.update_person(person, @invalid_attrs)
      assert person == CaseContext.get_person!(person.uuid)
    end

    test "delete_person/1 deletes the person" do
      person = person_fixture()
      assert {:ok, %Person{}} = CaseContext.delete_person(person)
      assert_raise Ecto.NoResultsError, fn -> CaseContext.get_person!(person.uuid) end
    end

    test "change_person/1 returns a person changeset" do
      person = person_fixture()
      assert %Ecto.Changeset{} = CaseContext.change_person(person)
    end

    test "person_has_mobile_number?/1 returns true if exists" do
      tenant = tenant_fixture()

      person =
        person_fixture(tenant, %{contact_methods: [%{type: :mobile, value: "+41787245790"}]})

      assert CaseContext.person_has_mobile_number?(person)
    end

    test "person_has_mobile_number?/1 returns false if not exists" do
      tenant = tenant_fixture()

      person = person_fixture(tenant, %{contact_methods: []})

      refute CaseContext.person_has_mobile_number?(person)
    end

    test "list_people_by_contact_method/2 finds relevant people" do
      tenant = tenant_fixture()

      person_matching =
        person_fixture(tenant, %{contact_methods: [%{type: :mobile, value: "+41878123456"}]})

      _person_not_matching_value =
        person_fixture(tenant, %{contact_methods: [%{type: :mobile, value: "+41878123458"}]})

      _person_not_matching_type =
        person_fixture(tenant, %{contact_methods: [%{type: :landline, value: "+41878123456"}]})

      assert [^person_matching] =
               CaseContext.list_people_by_contact_method(:mobile, "+41878123456")
    end

    test "list_people_by_name/2 finds relevant people" do
      tenant = tenant_fixture()

      person_matching = person_fixture(tenant, %{first_name: "Max", last_name: "Muster"})
      person_little_matching = person_fixture(tenant, %{first_name: "Maxi", last_name: "Muster"})

      _person_not_matching = person_fixture(tenant, %{first_name: "Peter", last_name: "Muster"})

      assert [^person_matching, ^person_little_matching] =
               CaseContext.list_people_by_name("Max", "Muster")
    end
  end

  describe "cases" do
    alias Hygeia.CaseContext.Case

    @valid_attrs %{
      complexity: :high,
      status: :first_contact,
      hospitalizations: [
        %{start: ~D[2020-10-13], end: ~D[2020-10-15]},
        %{start: ~D[2020-10-16], end: nil}
      ],
      clinical: %{
        reasons_for_pcr_test: [:symptoms, :outbreak_examination],
        symptoms: [:fever],
        symptom_start: ~D[2020-10-10],
        test: ~D[2020-10-11],
        laboratory_report: ~D[2020-10-12],
        test_kind: :pcr,
        result: :positive
      },
      external_references: [
        %{
          type: :ism,
          value: "7000"
        },
        %{
          type: :other,
          type_name: "foo",
          value: "7000"
        }
      ],
      monitoring: %{
        first_contact: ~D[2020-10-12],
        location: :home,
        location_details: "Bei Mutter zuhause",
        address: %{
          address: "Helmweg 48",
          zip: "8405",
          place: "Winterthur",
          subdivision: "ZH",
          country: "CH"
        }
      },
      phases: [
        %{
          type: :possible_index,
          start: ~D[2020-10-10],
          end: ~D[2020-10-12],
          end_reason: :converted_to_index
        },
        %{
          type: :index,
          start: ~D[2020-10-12],
          end: ~D[2020-10-22],
          end_reason: :healed
        }
      ]
    }
    @update_attrs %{
      complexity: :low,
      status: :done
    }
    @invalid_attrs %{
      complexity: nil,
      status: nil
    }

    test "list_cases/0 returns all cases" do
      case = case_fixture()
      assert CaseContext.list_cases() == [case]
    end

    test "get_case!/1 returns the case with given id" do
      case = case_fixture()
      assert CaseContext.get_case!(case.uuid) == case
    end

    test "create_case/1 with valid data creates a case" do
      tenant = %Tenant{uuid: tenant_uuid} = tenant_fixture()
      person = %Person{uuid: person_uuid} = person_fixture(tenant)
      user = %User{uuid: user_uuid} = user_fixture()
      organisation = organisation_fixture()

      assert {:ok,
              %Case{
                clinical: %Clinical{
                  laboratory_report: ~D[2020-10-12],
                  reasons_for_pcr_test: [:symptoms, :outbreak_examination],
                  result: :positive,
                  symptom_start: ~D[2020-10-10],
                  symptoms: [:fever],
                  test: ~D[2020-10-11],
                  test_kind: :pcr,
                  uuid: _
                },
                complexity: :high,
                external_references: [
                  %ExternalReference{type: :ism, type_name: nil, uuid: _, value: "7000"},
                  %ExternalReference{type: :other, type_name: "foo", uuid: _, value: "7000"}
                ],
                hospitalizations: [
                  %Hospitalization{end: ~D[2020-10-15], start: ~D[2020-10-13], uuid: _} =
                    hospitalization,
                  %Hospitalization{end: nil, start: ~D[2020-10-16], uuid: _}
                ],
                human_readable_id: _,
                inserted_at: _,
                monitoring: %Monitoring{
                  address: %Address{
                    address: "Helmweg 48",
                    country: "CH",
                    place: "Winterthur",
                    subdivision: "ZH",
                    uuid: _,
                    zip: "8405"
                  },
                  first_contact: ~D[2020-10-12],
                  location: :home,
                  location_details: "Bei Mutter zuhause",
                  uuid: _
                },
                phases: [
                  %Phase{
                    end: ~D[2020-10-12],
                    end_reason: :converted_to_index,
                    start: ~D[2020-10-10],
                    type: :possible_index,
                    uuid: _
                  },
                  %Phase{
                    end: ~D[2020-10-22],
                    end_reason: :healed,
                    start: ~D[2020-10-12],
                    type: :index,
                    uuid: _
                  }
                ],
                person: _,
                person_uuid: ^person_uuid,
                status: :first_contact,
                supervisor: _,
                supervisor_uuid: ^user_uuid,
                tenant: _,
                tenant_uuid: ^tenant_uuid,
                tracer: _,
                tracer_uuid: ^user_uuid,
                updated_at: _,
                uuid: _
              }} =
               CaseContext.create_case(
                 person,
                 @valid_attrs
                 |> Map.merge(%{tracer_uuid: user.uuid, supervisor_uuid: user.uuid})
                 |> put_in(
                   [:hospitalizations, Access.at(0), :organisation_uuid],
                   organisation.uuid
                 )
               )

      assert %Hospitalization{organisation: %Organisation{}} =
               Repo.preload(hospitalization, :organisation)
    end

    test "create_case/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               CaseContext.create_case(person_fixture(), @invalid_attrs)
    end

    test "update_case/2 with valid data updates the case" do
      case = case_fixture()

      assert {:ok,
              %Case{
                complexity: :low,
                status: :done
              }} = CaseContext.update_case(case, @update_attrs)
    end

    test "update_case/2 with invalid data returns error changeset" do
      case = case_fixture()
      assert {:error, %Ecto.Changeset{}} = CaseContext.update_case(case, @invalid_attrs)
      assert case == CaseContext.get_case!(case.uuid)
    end

    test "delete_case/1 deletes the case" do
      case = case_fixture()
      assert {:ok, %Case{}} = CaseContext.delete_case(case)
      assert_raise Ecto.NoResultsError, fn -> CaseContext.get_case!(case.uuid) end
    end

    test "change_case/1 returns a case changeset" do
      case = case_fixture()
      assert %Ecto.Changeset{} = CaseContext.change_case(case)
    end

    test "relate_case_to_organisation/2 relates organisation" do
      case = case_fixture()
      organisation = organisation_fixture()

      {:ok, %Case{related_organisations: [^organisation]}} =
        CaseContext.relate_case_to_organisation(case, organisation)
    end

    test "case_send_sms/2 sends sms" do
      delivery_receipt_id = Ecto.UUID.generate()

      expect(Hygeia.SmsSenderMock, :send, fn _message_id, _number, _text ->
        {:ok, delivery_receipt_id}
      end)

      case = case_fixture()

      assert {:ok,
              %ProtocolEntry{entry: %Sms{text: "Text", delivery_receipt_id: ^delivery_receipt_id}}} =
               CaseContext.case_send_sms(case, "Text")
    end

    test "case_send_sms/2 gives error when transport fails" do
      expect(Hygeia.SmsSenderMock, :send, fn _message_id, _number, _text ->
        {:error, "reason"}
      end)

      case = case_fixture()

      assert {:error, "reason"} = CaseContext.case_send_sms(case, "Text")
    end

    test "case_send_sms/2 gives error when no mobile number present" do
      tenant = tenant_fixture()
      person = person_fixture(tenant, %{contact_methods: []})
      case = case_fixture(person)

      assert {:error, :no_mobile_number} = CaseContext.case_send_sms(case, "Text")
    end
  end

  describe "transmissions" do
    alias Hygeia.CaseContext.Transmission

    @valid_attrs %{
      date: ~D[2010-04-17]
    }
    @update_attrs %{
      date: ~D[2011-05-18]
    }
    @invalid_attrs %{
      date: nil,
      propagator_ims_id: "00000",
      propagator_internal: true,
      recipient_ims_id: nil,
      recipient_internal: nil
    }

    test "list_transmissions/0 returns all transmissions" do
      index_case = case_fixture()

      transmission =
        transmission_fixture(%{
          propagator_internal: true,
          propagator_case_uuid: index_case.uuid
        })

      assert CaseContext.list_transmissions() == [transmission]
    end

    test "get_transmission!/1 returns the transmission with given id" do
      index_case = case_fixture()

      transmission =
        transmission_fixture(%{
          propagator_internal: true,
          propagator_case_uuid: index_case.uuid
        })

      assert CaseContext.get_transmission!(transmission.uuid) == transmission
    end

    test "create_transmission/1 with valid data creates a transmission" do
      index_case = case_fixture()

      assert {:ok, %Transmission{} = transmission} =
               %{
                 propagator_internal: true,
                 propagator_case_uuid: index_case.uuid
               }
               |> Enum.into(@valid_attrs)
               |> CaseContext.create_transmission()

      assert transmission.date == ~D[2010-04-17]
    end

    test "create_transmission/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = CaseContext.create_transmission(@invalid_attrs)
    end

    test "update_transmission/2 with valid data updates the transmission" do
      index_case = case_fixture()

      transmission =
        transmission_fixture(%{
          propagator_internal: true,
          propagator_case_uuid: index_case.uuid
        })

      assert {:ok, %Transmission{} = transmission} =
               CaseContext.update_transmission(transmission, @update_attrs)

      assert transmission.date == ~D[2011-05-18]
    end

    test "update_transmission/2 with invalid data returns error changeset" do
      index_case = case_fixture()

      transmission =
        transmission_fixture(%{
          propagator_internal: true,
          propagator_case_uuid: index_case.uuid
        })

      assert {:error, %Ecto.Changeset{}} =
               CaseContext.update_transmission(transmission, @invalid_attrs)

      assert transmission == CaseContext.get_transmission!(transmission.uuid)
    end

    test "delete_transmission/1 deletes the transmission" do
      index_case = case_fixture()

      transmission =
        transmission_fixture(%{
          propagator_internal: true,
          propagator_case_uuid: index_case.uuid
        })

      assert {:ok, %Transmission{}} = CaseContext.delete_transmission(transmission)
      assert_raise Ecto.NoResultsError, fn -> CaseContext.get_transmission!(transmission.uuid) end
    end

    test "change_transmission/1 returns a transmission changeset" do
      index_case = case_fixture()

      transmission =
        transmission_fixture(%{
          propagator_internal: true,
          propagator_case_uuid: index_case.uuid
        })

      assert %Ecto.Changeset{} = CaseContext.change_transmission(transmission)
    end
  end

  describe "protocol_entries" do
    alias Hygeia.CaseContext.ProtocolEntry

    @valid_attrs %{entry: %{__type__: "note", note: "some note"}}
    @update_attrs %{entry: %{__type__: "note", note: "some other note"}}
    @invalid_attrs %{entry: %{__type__: :invalid}}

    test "list_protocol_entries/0 returns all protocol_entries" do
      protocol_entry = protocol_entry_fixture()
      assert CaseContext.list_protocol_entries() == [protocol_entry]
    end

    test "get_protocol_entry!/1 returns the protocol_entry with given id" do
      protocol_entry = protocol_entry_fixture()
      assert CaseContext.get_protocol_entry!(protocol_entry.uuid) == protocol_entry
    end

    test "create_protocol_entry/1 with valid data creates a protocol_entry" do
      case = case_fixture()

      assert {:ok, %ProtocolEntry{entry: %Note{note: "some note"}}} =
               CaseContext.create_protocol_entry(case, @valid_attrs)
    end

    test "create_protocol_entry/1 with invalid data returns error changeset" do
      case = case_fixture()
      assert {:error, %Ecto.Changeset{}} = CaseContext.create_protocol_entry(case, @invalid_attrs)
    end

    test "update_protocol_entry/2 with valid data updates the protocol_entry" do
      protocol_entry = protocol_entry_fixture()

      assert {:ok, %ProtocolEntry{entry: %Note{note: "some other note"}}} =
               CaseContext.update_protocol_entry(protocol_entry, @update_attrs)
    end

    test "update_protocol_entry/2 with invalid data returns error changeset" do
      protocol_entry = protocol_entry_fixture()

      assert {:error, %Ecto.Changeset{}} =
               CaseContext.update_protocol_entry(protocol_entry, @invalid_attrs)

      assert protocol_entry == CaseContext.get_protocol_entry!(protocol_entry.uuid)
    end

    test "delete_protocol_entry/1 deletes the protocol_entry" do
      protocol_entry = protocol_entry_fixture()
      assert {:ok, %ProtocolEntry{}} = CaseContext.delete_protocol_entry(protocol_entry)

      assert_raise Ecto.NoResultsError, fn ->
        CaseContext.get_protocol_entry!(protocol_entry.uuid)
      end
    end

    test "change_protocol_entry/1 returns a protocol_entry changeset" do
      protocol_entry = protocol_entry_fixture()
      assert %Ecto.Changeset{} = CaseContext.change_protocol_entry(protocol_entry)
    end
  end
end
