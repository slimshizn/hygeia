defmodule Hygeia.Helpers.Phone do
  @moduledoc false

  import Ecto.Changeset

  alias Ecto.Changeset

  @origin_country Application.compile_env!(:hygeia, [:phone_number_parsing_origin_country])

  @spec validate_and_normalize_phone(
          changeset :: Changeset.t(),
          field :: atom,
          (atom -> :ok | {:error, term})
        ) ::
          Changeset.t()
  def validate_and_normalize_phone(changeset, field, type \\ fn _type -> :ok end) do
    with {:ok, phone_number} <- fetch_change(changeset, field),
         {:ok, parsed_number} <-
           ExPhoneNumber.parse(phone_number, @origin_country),
         true <- ExPhoneNumber.is_valid_number?(parsed_number),
         phone_number_type <- ExPhoneNumber.Validation.get_number_type(parsed_number),
         :ok <- type.(phone_number_type) do
      put_change(changeset, field, ExPhoneNumber.Formatting.format(parsed_number, :e164))
    else
      :error ->
        changeset

      {:ok, nil} ->
        changeset

      {:error, reason} when is_binary(reason) ->
        add_error(changeset, field, reason)

      {:error, _reason} ->
        add_error(changeset, field, "is invalid")

      false ->
        add_error(changeset, field, "is invalid")
    end
  end
end
