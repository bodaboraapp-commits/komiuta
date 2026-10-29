defmodule Xpressbus.BannersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Xpressbus.Banners` context.
  """

  @doc """
  Generate a banner.
  """
  def banner_fixture(attrs \\ %{}) do
    {:ok, banner} =
      attrs
      |> Enum.into(%{
        color: "some color",
        image: "some image",
        status: "some status"
      })
      |> Xpressbus.Banners.create_banner()

    banner
  end
end
