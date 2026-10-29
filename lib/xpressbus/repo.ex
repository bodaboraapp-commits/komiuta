defmodule Xpressbus.Repo do
  use Ecto.Repo,
    otp_app: :xpressbus,
    adapter: Ecto.Adapters.MyXQL
end
