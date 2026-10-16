defmodule ViraChat.Chat do
  import Ecto.Query
  alias ViraChat.Repo
  alias ViraChat.Chat.{Conversation, Participant, Message, MessageReaction, MessageStar}
  alias ViraChat.Accounts.User
  alias ViraChat.Accounts.Block

  # ------------------------------------------------------------------
  # Conversations
  # ------------------------------------------------------------------

  def list_conversations_for_user(user_id) do
    from(c in Conversation,
      join: p in Participant, on: p.conversation_id == c.id,
      where: p.user_id == ^user_id,
      order_by: [desc_nulls_last: p.pinned_at, desc: c.updated_at],
      preload: [:users],
      select: {c, p}
    )
    |> Repo.all()
    |> Enum.map(fn {conv, participant} ->
      Map.put(conv, :participant, participant)
    end)
  end

  def get_conversation!(id), do: Repo.get!(Conversation, id)

  def get_conversation_with_participants!(id) do
    Repo.get!(Conversation, id) |> Repo.preload(:users)
  end

  def create_private_conversation(user1_id, user2_id) do
    existing =
      from(c in Conversation,
        join: p1 in Participant, on: p1.conversation_id == c.id,
        join: p2 in Participant, on: p2.conversation_id == c.id,
        where: c.type == "private",
        where: p1.user_id == ^user1_id and p2.user_id == ^user2_id,
        limit: 1
      )
      |> Repo.one()

    case existing do
      nil ->
        Repo.transaction(fn ->
          {:ok, conversation} =
            %Conversation{}
            |> Conversation.changeset(%{type: "private"})
            |> Repo.insert()

          for uid <- [user1_id, user2_id] do
            {:ok, _} =
              %Participant{}
              |> Participant.changeset(%{user_id: uid, conversation_id: conversation.id})
              |> Repo.insert()
          end

          conversation
        end)
        |> case do
          {:ok, conversation} -> {:ok, conversation}
          {:error, reason} -> {:error, reason}
        end

      conversation ->
        {:ok, conversation}
    end
  end

  def create_group_conversation(title, creator_id, user_ids) do
    user_ids = Enum.uniq([creator_id | user_ids])

    Repo.transaction(fn ->
      {:ok, conversation} =
        %Conversation{}
        |> Conversation.changeset(%{type: "group", title: title})
        |> Repo.insert()

      for uid <- user_ids do
        {:ok, _} =
          %Participant{}
          |> Participant.changeset(%{user_id: uid, conversation_id: conversation.id})
          |> Repo.insert()
      end

      Repo.preload(conversation, :users)
    end)
    |> case do
      {:ok, conversation} -> {:ok, conversation}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_users_in_conversation(conversation_id) do
    from(u in User,
      join: p in Participant, on: p.user_id == u.id,
      where: p.conversation_id == ^conversation_id,
      order_by: [asc: u.email]
    )
    |> Repo.all()
  end

  def participant?(conversation_id, user_id) do
    from(p in Participant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  def list_all_users(exclude_user_id) do
    from(u in User, where: u.id != ^exclude_user_id, order_by: [asc: u.email])
    |> Repo.all()
  end

  # ------------------------------------------------------------------
  # Messages
  # ------------------------------------------------------------------

  def list_messages(conversation_id) do
    from(m in Message,
      where: m.conversation_id == ^conversation_id,
      order_by: [asc: m.inserted_at],
      preload: [:user, :forwarded_from, reply_to: :user, reactions: :user]
    )
    |> Repo.all()
  end

  def get_message!(id) do
    Repo.get!(Message, id)
    |> Repo.preload([:user, :forwarded_from, reply_to: :user, reactions: :user])
  end

  def reload_message(message_id) do
    get_message!(message_id)
  end

  def create_message(conversation_id, user_id, content) do
    create_message_with_media(conversation_id, user_id, content, nil, nil)
  end

  def create_message_with_media(conversation_id, user_id, content, media_url, reply_to_id \\ nil) do
    Repo.transaction(fn ->
      case %Message{}
           |> Message.changeset(%{
             conversation_id: conversation_id,
             user_id: user_id,
             content: content,
             media_url: media_url,
             reply_to_id: reply_to_id
           })
           |> Repo.insert() do
        {:ok, message} ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          from(c in Conversation, where: c.id == ^conversation_id)
          |> Repo.update_all(set: [updated_at: now])

          Repo.preload(message, [:user, :forwarded_from, reply_to: :user, reactions: :user])

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def edit_message(message_id, user_id, content) do
    message = Repo.get!(Message, message_id)

    cond do
      message.user_id != user_id ->
        {:error, :unauthorized}

      message.deleted_at != nil ->
        {:error, :deleted}

      String.trim(content) == "" ->
        {:error, :empty}

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        message
        |> Message.edit_changeset(%{content: String.trim(content), edited_at: now})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            {:ok, Repo.preload(updated, [:user, :forwarded_from, reply_to: :user, reactions: :user])}

          error ->
            error
        end
    end
  end

  def delete_message(message_id, user_id) do
    message = Repo.get!(Message, message_id)

    cond do
      message.user_id != user_id ->
        {:error, :unauthorized}

      message.deleted_at != nil ->
        {:error, :already_deleted}

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        message
        |> Message.delete_changeset(%{deleted_at: now})
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            {:ok, Repo.preload(updated, [:user, :forwarded_from, reply_to: :user, reactions: :user])}

          error ->
            error
        end
    end
  end

  # ------------------------------------------------------------------
  # Search
  # ------------------------------------------------------------------

  def search_messages(user_id, query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 30)
    query = String.trim(query)

    if query == "" do
      []
    else
      pattern = "%#{query}%"

      from(m in Message,
        join: c in Conversation, on: c.id == m.conversation_id,
        join: p in Participant, on: p.conversation_id == c.id,
        where: p.user_id == ^user_id,
        where: is_nil(m.deleted_at),
        where: ilike(m.content, ^pattern),
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:user]
      )
      |> Repo.all()
    end
  end

  # ------------------------------------------------------------------
  # Read receipts + unread counts
  # ------------------------------------------------------------------

  def mark_conversation_read(conversation_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(p in Participant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.update_all(set: [last_read_at: now, updated_at: now])
  end

  def last_read_at_for(conversation_id, user_id) do
    from(p in Participant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id,
      select: p.last_read_at
    )
    |> Repo.one()
  end

  def unread_counts_for_user(user_id) do
    from(m in Message,
      join: p in Participant, on: p.conversation_id == m.conversation_id,
      where: p.user_id == ^user_id,
      where: m.user_id != ^user_id,
      where: is_nil(p.last_read_at) or m.inserted_at > p.last_read_at,
      group_by: m.conversation_id,
      select: {m.conversation_id, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # ------------------------------------------------------------------
  # Reactions
  # ------------------------------------------------------------------

  def toggle_reaction(message_id, user_id, emoji) do
    existing =
      from(r in MessageReaction,
        where: r.message_id == ^message_id and r.user_id == ^user_id and r.emoji == ^emoji
      )
      |> Repo.one()

    case existing do
      nil ->
        %MessageReaction{}
        |> MessageReaction.changeset(%{
          message_id: message_id,
          user_id: user_id,
          emoji: emoji
        })
        |> Repo.insert()

      reaction ->
        Repo.delete(reaction)
    end
  end

  # ------------------------------------------------------------------
  # Mentions
  # ------------------------------------------------------------------

  def extract_mentions(content, participants) when is_binary(content) do
    Enum.filter(participants, fn user ->
      name = User.display_name(user)
      prefix = user.email |> String.split("@") |> List.first()

      Regex.match?(~r/(?:^|\s)@#{Regex.escape(name)}(?:\s|$|[[:punct:]])/iu, content) or
        Regex.match?(~r/(?:^|\s)@#{Regex.escape(prefix)}(?:\s|$|[[:punct:]])/iu, content)
    end)
  end

  def extract_mentions(_content, _participants), do: []

  @everyone_aliases ["here", "everyone"]

  def has_everyone_mention?(content) when is_binary(content) do
    Enum.any?(@everyone_aliases, fn alias_ ->
      Regex.match?(~r/(?:^|\s)@#{alias_}(?=\s|$|[[:punct:]])/i, content)
    end)
  end

  def has_everyone_mention?(_), do: false

  # ------------------------------------------------------------------
  # Presence helpers
  # ------------------------------------------------------------------

  def touch_last_seen(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(u in User, where: u.id == ^user_id)
    |> Repo.update_all(set: [last_seen_at: now])
  end

  # ------------------------------------------------------------------
  # Participant controls: mute / pin / archive / leave
  # ------------------------------------------------------------------

  defp get_participant(conversation_id, user_id) do
    from(p in Participant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.one()
  end

  def toggle_mute(conversation_id, user_id) do
    participant = get_participant(conversation_id, user_id)

    cond do
      is_nil(participant) ->
        {:error, :not_a_participant}

      is_nil(participant.muted_at) ->
        participant
        |> Ecto.Changeset.change(muted_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()

      true ->
        participant
        |> Ecto.Changeset.change(muted_at: nil)
        |> Repo.update()
    end
  end

  def toggle_pin(conversation_id, user_id) do
    participant = get_participant(conversation_id, user_id)

    cond do
      is_nil(participant) ->
        {:error, :not_a_participant}

      is_nil(participant.pinned_at) ->
        participant
        |> Ecto.Changeset.change(pinned_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()

      true ->
        participant
        |> Ecto.Changeset.change(pinned_at: nil)
        |> Repo.update()
    end
  end

  def toggle_archive(conversation_id, user_id) do
    participant = get_participant(conversation_id, user_id)

    cond do
      is_nil(participant) ->
        {:error, :not_a_participant}

      is_nil(participant.archived_at) ->
        participant
        |> Ecto.Changeset.change(archived_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()

      true ->
        participant
        |> Ecto.Changeset.change(archived_at: nil)
        |> Repo.update()
    end
  end

  def muted?(conversation_id, user_id) do
    case get_participant(conversation_id, user_id) do
      %{muted_at: muted} when not is_nil(muted) -> true
      _ -> false
    end
  end

  def leave_group(conversation_id, user_id) do
    participant = get_participant(conversation_id, user_id)

    cond do
      is_nil(participant) -> {:error, :not_a_participant}
      true -> Repo.delete(participant)
    end
  end

  # ------------------------------------------------------------------
  # Blocks
  # ------------------------------------------------------------------

  def list_blocked_ids(user_id) do
    from(b in Block, where: b.blocker_id == ^user_id, select: b.blocked_id)
    |> Repo.all()
    |> MapSet.new()
  end

  def blocked?(blocker_id, blocked_id) do
    from(b in Block,
      where: b.blocker_id == ^blocker_id and b.blocked_id == ^blocked_id
    )
    |> Repo.exists?()
  end

  def blocked_between?(a_id, b_id) do
    from(b in Block,
      where:
        (b.blocker_id == ^a_id and b.blocked_id == ^b_id) or
          (b.blocker_id == ^b_id and b.blocked_id == ^a_id)
    )
    |> Repo.exists?()
  end

  def block_user(blocker_id, blocked_id) do
    %Block{}
    |> Block.changeset(%{blocker_id: blocker_id, blocked_id: blocked_id})
    |> Repo.insert()
  end

  def unblock_user(blocker_id, blocked_id) do
    from(b in Block, where: b.blocker_id == ^blocker_id and b.blocked_id == ^blocked_id)
    |> Repo.delete_all()

    {:ok, :unblocked}
  end

  def list_blocked_users(blocker_id) do
    from(b in Block,
      where: b.blocker_id == ^blocker_id,
      preload: [:blocked],
      order_by: [desc: b.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(& &1.blocked)
  end

  # ------------------------------------------------------------------
  # Message stars
  # ------------------------------------------------------------------

  def star_message(message_id, user_id) do
    %MessageStar{}
    |> MessageStar.changeset(%{message_id: message_id, user_id: user_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:message_id, :user_id])
  end

  def unstar_message(message_id, user_id) do
    from(s in MessageStar,
      where: s.message_id == ^message_id and s.user_id == ^user_id
    )
    |> Repo.delete_all()

    {:ok, :unstarred}
  end

  def starred?(message_id, user_id) do
    from(s in MessageStar,
      where: s.message_id == ^message_id and s.user_id == ^user_id
    )
    |> Repo.exists?()
  end

  def list_starred_messages(user_id) do
    from(m in Message,
      join: s in MessageStar, on: s.message_id == m.id,
      where: s.user_id == ^user_id,
      where: is_nil(m.deleted_at),
      order_by: [desc: s.inserted_at],
      preload: [:user, conversation: :users]
    )
    |> Repo.all()
  end

  def starred_message_ids_for(user_id, message_ids) when is_list(message_ids) do
    from(s in MessageStar,
      where: s.user_id == ^user_id and s.message_id in ^message_ids,
      select: s.message_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  # ------------------------------------------------------------------
  # Forwarding
  # ------------------------------------------------------------------

  def forward_message(original_message_id, target_conversation_id, sender_id) do
    original = get_message!(original_message_id)

    Repo.transaction(fn ->
      {:ok, new_message} =
        create_message_with_media(
          target_conversation_id,
          sender_id,
          original.content,
          original.media_url,
          nil
        )

      new_message
      |> Ecto.Changeset.change(forwarded_from_id: original.id)
      |> Repo.update!()
      |> then(fn m -> Repo.preload(m, [:user, :forwarded_from, :reply_to, :reactions]) end)
    end)
  end

  # ------------------------------------------------------------------
  # Delivered ticks
  # ------------------------------------------------------------------

  def mark_conversation_delivered(conversation_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(p in Participant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.update_all(set: [delivered_at: now])
  end

  def delivered_at_for(conversation_id, user_id) do
    from(p in Participant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id,
      select: p.delivered_at
    )
    |> Repo.one()
  end

  # ------------------------------------------------------------------
  # Link preview (called after message insert)
  # ------------------------------------------------------------------

  def attach_link_preview(message_id, preview) when is_map(preview) do
    from(m in Message, where: m.id == ^message_id)
    |> Repo.update_all(set: [link_preview: preview])

    reload_message(message_id)
  end
end
