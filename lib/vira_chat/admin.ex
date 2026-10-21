defmodule ViraChat.Admin do
  import Ecto.Query
  alias ViraChat.Repo
  alias ViraChat.Accounts.User
  alias ViraChat.Chat.{Conversation, Message}
  alias ViraChat.Admin.AdminAction

  # --- Stats ---

  def stats do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    day_ago = DateTime.add(now, -86_400, :second)

    %{
      users: Repo.aggregate(User, :count),
      admins: Repo.aggregate(from(u in User, where: u.role in ["admin", "superuser"]), :count),
      banned: Repo.aggregate(from(u in User, where: not is_nil(u.banned_at)), :count),
      conversations: Repo.aggregate(Conversation, :count),
      messages: Repo.aggregate(Message, :count),
      messages_24h: Repo.aggregate(from(m in Message, where: m.inserted_at > ^day_ago), :count),
      users_24h: Repo.aggregate(from(u in User, where: u.inserted_at > ^day_ago), :count),
      online_now: map_size(ViraChatWeb.Presence.list("online_users"))
    }
  end

  # --- Users ---

  def list_users(search \\ "", opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    query =
      from u in User,
        order_by: [desc: u.inserted_at],
        limit: ^limit

    query =
      if search != "" do
        where(query, [u], ilike(u.email, ^"%#{search}%"))
      else
        query
      end

    Repo.all(query)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def change_role(user, role, actor) when role in ["user", "admin", "superuser"] do
    cond do
      not User.superuser?(actor) ->
        {:error, :forbidden}

      user.id == actor.id and role != "superuser" ->
        {:error, :cannot_demote_self}

      true ->
        old_role = user.role

        case user
             |> Ecto.Changeset.change(role: role)
             |> Repo.update() do
          {:ok, updated} ->
            log_action(actor, updated, "change_role", %{
              "from" => old_role,
              "to" => role
            })

            {:ok, updated}

          error ->
            error
        end
    end
  end

  def ban_user(user, actor) do
    case user
         |> Ecto.Changeset.change(banned_at: DateTime.utc_now() |> DateTime.truncate(:second))
         |> Repo.update() do
      {:ok, updated} ->
        log_action(actor, updated, "ban_user", %{})
        {:ok, updated}

      error ->
        error
    end
  end

  def unban_user(user, actor) do
    case user
         |> Ecto.Changeset.change(banned_at: nil)
         |> Repo.update() do
      {:ok, updated} ->
        log_action(actor, updated, "unban_user", %{})
        {:ok, updated}

      error ->
        error
    end
  end

  def delete_user(user, actor) do
    email = user.email
    user_id = user.id

    case Repo.delete(user) do
      {:ok, deleted} ->
        log_action(actor, nil, "delete_user", %{
          "user_id" => user_id,
          "email" => email
        })

        {:ok, deleted}

      error ->
        error
    end
  end

  # --- Conversations ---

  def list_conversations(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(c in Conversation,
      order_by: [desc: c.updated_at],
      limit: ^limit,
      preload: [:users]
    )
    |> Repo.all()
    |> Enum.map(fn c ->
      msg_count =
        from(m in Message, where: m.conversation_id == ^c.id)
        |> Repo.aggregate(:count)

      Map.put(c, :message_count, msg_count)
    end)
  end

  def get_conversation!(id) do
    Repo.get!(Conversation, id) |> Repo.preload(users: [], messages: [:user])
  end

  def delete_conversation(conversation, actor) do
    conv_id = conversation.id
    participants = Enum.map(conversation.users, & &1.email)
    msg_count = length(conversation.messages || [])

    case Repo.delete(conversation) do
      {:ok, deleted} ->
        log_action(actor, nil, "delete_conversation", %{
          "conversation_id" => conv_id,
          "type" => conversation.type,
          "title" => conversation.title,
          "participants" => participants,
          "message_count" => msg_count
        })

        {:ok, deleted}

      error ->
        error
    end
  end

  def delete_message(message), do: Repo.delete(message)

  def recent_messages(limit \\ 20) do
    from(m in Message,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  # --- Audit log ---

  @doc """
  Writes an audit row. Called from every admin mutation.
  """
  def log_action(actor, target_user, action, details \\ %{}) do
    %AdminAction{}
    |> AdminAction.changeset(%{
      actor_id: actor.id,
      target_user_id: target_user && target_user.id,
      action: action,
      details: details
    })
    |> Repo.insert()
  end

  @doc """
  Returns recent audit entries, newest first, with actor and target preloaded.

  Options:
    * `:action` — filter by action string (optional)
    * `:actor_id` — filter by actor (optional)
    * `:limit` — max rows (default 100)
  """
  def list_audit_actions(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    action = Keyword.get(opts, :action)
    actor_id = Keyword.get(opts, :actor_id)

    query =
      from(a in AdminAction,
        order_by: [desc: a.inserted_at],
        limit: ^limit,
        preload: [:actor, :target_user]
      )

    query = if action && action != "", do: where(query, [a], a.action == ^action), else: query
    query = if actor_id, do: where(query, [a], a.actor_id == ^actor_id), else: query

    Repo.all(query)
  end

  @doc """
  Distinct action strings that have ever been logged — used for the filter dropdown.
  """
  def distinct_actions do
    from(a in AdminAction, distinct: true, select: a.action, order_by: a.action)
    |> Repo.all()
  end
end
