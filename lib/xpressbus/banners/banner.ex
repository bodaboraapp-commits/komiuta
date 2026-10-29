defmodule Xpressbus.Banners.Banner do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "banners" do
    field(:image, :string)
    field(:status, :string)
    field(:color, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(banner, attrs) do
    banner
    |> cast(attrs, [:image, :status, :color])
    |> validate_required([:image, :status, :color])
  end
end
