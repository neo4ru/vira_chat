defmodule ViraChat.Calls do
  @moduledoc """
  Call history: logging calls and reading a user's call list.
  """
  import Ecto.Query

  alias ViraChat.Repo
  alias ViraChat.Calls.CallLog

  @doc """
  Logs a new call. Returns `{:ok, call_log}` or `{:error, changeset}`.
  """
  def log_call(attrs) do
    %CallLog{}
    |> CallLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing call log.
  """
  def update_call(nil, _attrs), do: {:error, :not_found}

  def update_call(id, attrs) do
    case Repo.get(CallLog, id) do
      nil -> {:error, :not_found}
      call_log -> call_log |> CallLog.changeset(attrs) |> Repo.update()
    end
  end

  @doc """
  Lists a user's calls, newest first. Filter is one of "all", "missed", "video".
  """
  def list_calls_for_user(user_id, opts \\ []) do
    filter = Keyword.get(opts, :filter, "all")

    CallLog
    |> where([c], c.caller_id == ^user_id or c.callee_id == ^user_id)
    |> apply_filter(filter)
    |> order_by([c], desc: c.inserted_at)
    |> limit(100)
    |> preload([:caller, :callee, :conversation])
    |> Repo.all()
  end

  defp apply_filter(query, "missed") do
    where(query, [c], c.status in ["missed", "declined"])
  end

  defp apply_filter(query, "video") do
    where(query, [c], c.call_type == "video")
  end

  defp apply_filter(query, _), do: query

  @doc """
  Counts for the call page: total, missed/declined and video calls.
  """
  def stats_for_user(user_id) do
    base =
      CallLog
      |> where([c], c.caller_id == ^user_id or c.callee_id == ^user_id)

    %{
      total: Repo.aggregate(base, :count, :id),
      missed:
        Repo.aggregate(from(c in base, where: c.status in ["missed", "declined"]), :count, :id),
      video: Repo.aggregate(from(c in base, where: c.call_type == "video"), :count, :id)
    }
  end

  @doc """
  Fetches a call log the user participated in.
  """
  def get_call(id, user_id) do
    CallLog
    |> where([c], c.id == ^id and (c.caller_id == ^user_id or c.callee_id == ^user_id))
    |> preload([:caller, :callee, :conversation])
    |> Repo.one()
  end
end
