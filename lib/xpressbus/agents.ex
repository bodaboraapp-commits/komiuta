defmodule Xpressbus.Agents do
  @moduledoc """
  Agent onboarding applications submitted from the Komiuta Agent PWA.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Agents.AgentApplication

  @page_size 20

  def create_application(attrs) do
    reference = "AGT-" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :upper))

    %AgentApplication{}
    |> AgentApplication.changeset(Map.put(attrs, "reference", reference))
    |> Repo.insert()
  end

  def list_applications do
    Repo.all(from(a in AgentApplication, order_by: [desc: a.inserted_at]))
  end

  def paginate_applications(page, page_size \\ @page_size, search \\ "") do
    search = String.trim(to_string(search || ""))
    pattern = "%#{search}%"

    query = from(a in AgentApplication, order_by: [desc: a.inserted_at])

    query =
      if search == "" do
        query
      else
        where(
          query,
          [a],
          fragment("LOWER(?) LIKE LOWER(?)", a.full_name, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.business_name, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.email, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.phone, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", a.reference, ^pattern)
        )
      end

    total = Repo.aggregate(query, :count, :id)

    applications =
      query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    {applications, total}
  end

  def get_application!(id), do: Repo.get!(AgentApplication, id)

  def update_status(%AgentApplication{} = application, status, admin_notes \\ nil)
      when status in ["pending", "approved", "rejected"] do
    application
    |> AgentApplication.changeset(%{
      status: status,
      admin_notes: admin_notes || application.admin_notes,
      reviewed_at:
        if(status == "pending", do: nil, else: DateTime.utc_now() |> DateTime.truncate(:second))
    })
    |> Repo.update()
  end

  def count_pending do
    Repo.aggregate(from(a in AgentApplication, where: a.status == "pending"), :count, :id)
  end
end
