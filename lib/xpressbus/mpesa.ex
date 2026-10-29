defmodule Xpressbus.Mpesa do
  @moduledoc """
  The Mpesa context handles MPESA Daraja API settings.
  """

  alias Xpressbus.Repo
  alias Xpressbus.Mpesa.MpesaSetting

  @doc """
  Returns the current MPESA settings.
  """
  def get_mpesa_setting do
    Repo.one(MpesaSetting) || %MpesaSetting{mode: "sandbox"}
  end

  @doc """
  Creates or updates MPESA settings.
  """
  def upsert_mpesa_setting(attrs) do
    case Repo.one(MpesaSetting) do
      nil ->
        %MpesaSetting{}
        |> MpesaSetting.changeset(attrs)
        |> Repo.insert()

      setting ->
        setting
        |> MpesaSetting.changeset(attrs)
        |> Repo.update()
    end
  end
end
