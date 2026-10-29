defmodule Xpressbus.Insurance.InsuranceFaq do
  @moduledoc """
  A frequently asked question displayed on the InSURE page.

  Questions are ordered by `position` and can be hidden with `active: false`
  while keeping the row for editing later.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "insurance_faqs" do
    field(:question, :string)
    field(:answer, :string)
    field(:position, :integer, default: 0)
    field(:active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(faq, attrs) do
    faq
    |> cast(attrs, [:question, :answer, :position, :active])
    |> validate_required([:question, :answer])
    |> validate_length(:question, max: 250)
    |> validate_length(:answer, max: 2_000)
    |> unique_constraint(:question)
  end
end
