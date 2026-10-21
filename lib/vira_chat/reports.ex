defmodule ViraChat.Reports do
  import Ecto.Query
  alias ViraChat.Repo
  alias ViraChat.Admin.Report

  @doc """
  The list of reasons a message can be reported for.
  """
  defdelegate reasons(), to: Report

  @doc """
  A human friendly label for a report reason.
  """
  defdelegate reason_label(reason), to: Report

  @doc """
  A human friendly label for a report status.
  """
  defdelegate status_label(status), to: Report

  def create_report(reporter_id, attrs) do
    %Report{}
    |> Report.changeset(Map.put(attrs, :reporter_id, reporter_id))
    |> Repo.insert()
  end

  def list_reports(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    status = Keyword.get(opts, :status)

    query =
      from(r in Report,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        preload: [:reporter, :reported_user, :message, :resolved_by, :conversation]
      )

    query = if status && status != "", do: where(query, [r], r.status == ^status), else: query
    Repo.all(query)
  end

  def pending_count do
    from(r in Report, where: r.status == "pending", select: count(r.id))
    |> Repo.one()
  end

  def resolve_report(report_id, resolver_id, status) when status in ["resolved", "dismissed"] do
    report = Repo.get!(Report, report_id)

    report
    |> Report.resolve_changeset(resolver_id, status)
    |> Repo.update()
  end
end
