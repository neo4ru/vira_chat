defmodule ViraChatWeb.ChatLive do
  use ViraChatWeb, :live_view
  import ViraChatWeb.ChatComponents # <-- THIS LINE IS CRITICAL

  alias ViraChat.Chat
  alias ViraChat.Accounts.User
  alias ViraChat.LinkPreview
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(ViraChat.PubSub, "user:#{current_user.id}")

      ViraChatWeb.Presence.track(self(), "online_users", current_user.id, %{
        email: current_user.email,
        online_at: System.system_time(:second)
      })

      Chat.touch_last_seen(current_user.id)
    end

    conversations = Chat.list_conversations_for_user(current_user.id)
    blocked_ids = Chat.list_blocked_ids(current_user.id)

    all_users = Chat.list_all_users(current_user.id)
    users = Enum.reject(all_users, fn u -> MapSet.member?(blocked_ids, u.id) end)
    blocked_users = Enum.filter(all_users, fn u -> MapSet.member?(blocked_ids, u.id) end)

    online = list_online_users()
    unread_counts = Chat.unread_counts_for_user(current_user.id)

    {:ok,
     socket
     |> allow_upload(:image, accept: ~w(.jpg .jpeg .png .gif .webp), max_entries: 1, max_file_size: 10_000_000)
     |> allow_upload(:audio, accept: ~w(.webm .mp3), max_entries: 1, max_file_size: 25_000_000)
     |> allow_upload(:group_avatar, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 10_000_000)
     |> assign(:current_user, current_user)
     |> assign(:conversations, conversations)
     |> assign(:users, users)
     |> assign(:blocked_users, blocked_users)
     |> assign(:blocked_ids, blocked_ids)
     |> assign(:online_users, online)
     |> assign(:unread_counts, unread_counts)
     |> assign(:active_conversation, nil)
     |> assign(:messages, [])
     |> assign(:has_more_messages, false)
     |> assign(:message_offset, 0)
     |> assign(:message_form, to_form(%{"content" => ""}))
     |> assign(:show_new_chat, false)
     |> assign(:show_new_group, false)
     |> assign(:show_archived, false)
     |> assign(:show_menu_for, nil)
     |> assign(:show_blocked_modal, false)
     |> assign(:group_title, "")
     |> assign(:group_members, [])
     |> assign(:typing_users, [])
     |> assign(:readers, %{})
     |> assign(:delivereds, %{})
     |> assign(:editing_message_id, nil)
     |> assign(:edit_form, nil)
     |> assign(:reply_to, nil)
     |> assign(:push_enabled, false)
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:starred_message_ids, MapSet.new())
     |> assign(:forwarding_message_id, nil)
     |> assign(:reporting_message_id, nil)
     |> assign(:report_form, to_form(%{"reason" => "spam", "details" => ""}))
     |> assign(:show_info, false)
     |> assign(:info_tab, "members")
     |> assign(:participants, [])
     |> assign(:shared_media, [])
     |> assign(:group_title_form, to_form(%{"title" => ""}))
     |> assign(:show_add_member, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case params do
      %{"id" => id} ->
        conversation = Chat.get_conversation_with_participants!(id)

        if Chat.participant?(conversation.id, socket.assigns.current_user.id) do
          messages = Chat.list_messages(conversation.id, socket.assigns.current_user.id, limit: 50, offset: 0)
          has_more = length(messages) == 50

          Chat.mark_conversation_read(conversation.id, socket.assigns.current_user.id)
          Chat.mark_conversation_delivered(conversation.id, socket.assigns.current_user.id)

          for participant <- conversation.users, participant.id != socket.assigns.current_user.id do
            Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:conversation_delivered, conversation.id, socket.assigns.current_user.id})
            Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:conversation_read, conversation.id, socket.assigns.current_user.id})
          end

          readers = for p <- conversation.users, p.id != socket.assigns.current_user.id, into: %{}, do: {p.id, Chat.last_read_at_for(conversation.id, p.id)}
          delivereds = for p <- conversation.users, p.id != socket.assigns.current_user.id, into: %{}, do: {p.id, Chat.delivered_at_for(conversation.id, p.id)}
          starred = Chat.starred_message_ids_for(socket.assigns.current_user.id, Enum.map(messages, & &1.id))
          unread_counts = Map.put(socket.assigns.unread_counts, conversation.id, 0)

          {:noreply,
           socket
           |> assign(:active_conversation, conversation)
           |> assign(:messages, messages)
           |> assign(:has_more_messages, has_more)
           |> assign(:message_offset, 0)
           |> assign(:typing_users, [])
           |> assign(:readers, readers)
           |> assign(:delivereds, delivereds)
           |> assign(:unread_counts, unread_counts)
           |> assign(:editing_message_id, nil)
           |> assign(:edit_form, nil)
           |> assign(:reply_to, nil)
           |> assign(:show_menu_for, nil)
           |> assign(:starred_message_ids, starred)
           |> assign(:participants, Chat.list_participants_with_roles(conversation.id))
           |> assign(:shared_media, Chat.list_shared_media(conversation.id))
           |> assign(:show_info, false)
           |> assign(:show_add_member, false)
           |> assign(:group_title_form, to_form(%{"title" => conversation.title || ""}))}
        else
          {:noreply, socket |> put_flash(:error, "Not a participant") |> push_patch(to: ~p"/chat")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("load_older_messages", _params, socket) do
    conv = socket.assigns.active_conversation
    offset = socket.assigns.message_offset + 50
    older_messages = Chat.list_messages(conv.id, socket.assigns.current_user.id, limit: 50, offset: offset)

    if older_messages == [] do
      {:noreply, assign(socket, :has_more_messages, false)}
    else
      all_messages = older_messages ++ socket.assigns.messages
      {:noreply,
       socket
       |> assign(:messages, all_messages)
       |> assign(:message_offset, offset)
       |> assign(:has_more_messages, length(older_messages) == 50)}
    end
  end

  @impl true
  def handle_event("toggle_blocked_modal", _params, socket) do
    {:noreply, assign(socket, :show_blocked_modal, !socket.assigns.show_blocked_modal)}
  end

  @impl true
  def handle_event("delete_chat", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.delete_conversation_for_user(id, user.id)
    conversations = Chat.list_conversations_for_user(user.id)

    socket =
      if socket.assigns.active_conversation && socket.assigns.active_conversation.id == id do
        socket |> assign(:active_conversation, nil) |> assign(:messages, []) |> push_patch(to: ~p"/chat")
      else
        socket
      end

    {:noreply, socket |> assign(:conversations, conversations) |> assign(:show_menu_for, nil) |> put_flash(:info, "Chat deleted")}
  end

  @impl true
  def handle_event("clear_chat", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.clear_chat_history(id, user.id)

    socket =
      if socket.assigns.active_conversation && socket.assigns.active_conversation.id == id do
        socket |> assign(:messages, []) |> assign(:show_menu_for, nil)
      else
        socket |> assign(:show_menu_for, nil)
      end

    {:noreply, put_flash(socket, :info, "Chat cleared")}
  end

  # --- Group Info Events ---
  @impl true
  def handle_event("toggle_info", _params, socket), do: {:noreply, assign(socket, :show_info, !socket.assigns.show_info)}
  @impl true
  def handle_event("close_info", _params, socket), do: {:noreply, assign(socket, :show_info, false)}
  @impl true
  def handle_event("set_info_tab", %{"tab" => tab}, socket), do: {:noreply, assign(socket, :info_tab, tab)}
  @impl true
  def handle_event("toggle_add_member", _params, socket), do: {:noreply, assign(socket, :show_add_member, !socket.assigns.show_add_member)}

  @impl true
  def handle_event("add_member", %{"id" => user_id}, socket) do
    conv = socket.assigns.active_conversation
    user = socket.assigns.current_user
    target_id = String.to_integer(user_id)

    case Chat.add_group_member(conv.id, user.id, target_id) do
      {:ok, _} ->
        broadcast_group_update(conv.id)
        {:noreply,
         socket
         |> assign(:participants, Chat.list_participants_with_roles(conv.id))
         |> assign(:active_conversation, Chat.get_conversation_with_participants!(conv.id))
         |> assign(:show_add_member, false)
         |> put_flash(:info, "Member added")}
      {:error, :already_member} ->
        {:noreply, put_flash(socket, :error, "User is already in the group")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not add member")}
    end
  end

  @impl true
  def handle_event("validate_group_title", params, socket), do: {:noreply, assign(socket, :group_title_form, to_form(params))}

  @impl true
  def handle_event("save_group_title", %{"title" => title}, socket) do
    conv = socket.assigns.active_conversation
    user = socket.assigns.current_user

    case Chat.update_group_title(conv.id, user.id, title) do
      {:ok, _} ->
        broadcast_group_update(conv.id)
        {:noreply, socket |> assign(:active_conversation, Chat.get_conversation_with_participants!(conv.id)) |> put_flash(:info, "Title updated")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not update title")}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_avatar", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :group_avatar, ref)}
  end

  @impl true
  def handle_event("save_avatar", _params, socket) do
    conv = socket.assigns.active_conversation

    if is_nil(conv) do
      {:noreply, socket}
    else
      case socket.assigns.uploads.group_avatar.entries do
        [entry] ->
          if entry.valid? do
            avatar_url =
              socket
              |> consume_uploaded_entries(:group_avatar, fn %{path: path}, entry ->
                try do
                  ext = case Path.extname(entry.client_name) do "" -> ".png"; e -> e end
                  filename = "group_avatar_#{conv.id}_#{System.unique_integer([:positive])}#{ext}"
                  dest = Path.join(["priv", "static", "uploads", "groups", filename])

                  File.mkdir_p!(Path.dirname(dest))
                  File.cp!(path, dest)
                  Logger.info("✅ File successfully saved to #{dest}")
                  {:ok, "/uploads/groups/#{filename}"}
                rescue
                  e ->
                    Logger.error("❌ File upload failed: #{inspect(e)}")
                    {:error, e}
                end
              end)
              |> List.first()

            if avatar_url do
              conversation = Chat.get_conversation!(conv.id)
              changeset = Ecto.Changeset.change(conversation, avatar_url: avatar_url)

              case ViraChat.Repo.update(changeset) do
                {:ok, _} ->
                  Logger.info("✅ Database updated with new avatar_url: #{avatar_url}")
                  broadcast_group_update(conv.id)
                  {:noreply,
                   socket
                   |> assign(:active_conversation, Chat.get_conversation_with_participants!(conv.id))
                   |> put_flash(:info, "Avatar updated")}

                {:error, changeset} ->
                  Logger.error("❌ Database update failed: #{inspect(changeset.errors)}")
                  {:noreply, put_flash(socket, :error, "Could not save avatar to database")}
              end
            else
              {:noreply, put_flash(socket, :error, "Upload failed. Could not save file.")}
            end
          else
            {:noreply, put_flash(socket, :error, "Invalid file. Max size is 10MB.")}
          end
        _ ->
          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("promote_member", %{"id" => target_id}, socket) do
    conv = socket.assigns.active_conversation
    user = socket.assigns.current_user
    case Chat.promote_to_admin(conv.id, user.id, String.to_integer(target_id)) do
      {:ok, _} ->
        broadcast_group_update(conv.id)
        {:noreply, socket |> assign(:participants, Chat.list_participants_with_roles(conv.id))}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not promote member")}
    end
  end

  @impl true
  def handle_event("demote_member", %{"id" => target_id}, socket) do
    conv = socket.assigns.active_conversation
    user = socket.assigns.current_user
    case Chat.demote_from_admin(conv.id, user.id, String.to_integer(target_id)) do
      {:ok, _} ->
        broadcast_group_update(conv.id)
        {:noreply, socket |> assign(:participants, Chat.list_participants_with_roles(conv.id))}
      {:error, :last_admin} ->
        {:noreply, put_flash(socket, :error, "Cannot demote the last admin")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not demote member")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => target_id}, socket) do
    conv = socket.assigns.active_conversation
    user = socket.assigns.current_user
    case Chat.remove_from_group(conv.id, user.id, String.to_integer(target_id)) do
      {:ok, _} ->
        broadcast_group_update(conv.id)
        {:noreply,
         socket
         |> assign(:participants, Chat.list_participants_with_roles(conv.id))
         |> assign(:active_conversation, Chat.get_conversation_with_participants!(conv.id))
         |> put_flash(:info, "Member removed")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not remove member")}
    end
  end

  @impl true
  def handle_event("delete_group", _params, socket) do
    conv = socket.assigns.active_conversation
    user = socket.assigns.current_user
    case Chat.delete_group(conv.id, user.id) do
      {:ok, _} ->
        conversations = Chat.list_conversations_for_user(user.id)
        {:noreply,
         socket
         |> assign(:conversations, conversations)
         |> assign(:active_conversation, nil)
         |> assign(:messages, [])
         |> assign(:show_info, false)
         |> push_patch(to: ~p"/chat")
         |> put_flash(:info, "Group deleted")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not delete group")}
    end
  end

  # --- Standard Events ---
  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
    results = Chat.search_messages(socket.assigns.current_user.id, query)
    {:noreply, socket |> assign(:search_query, query) |> assign(:search_results, results)}
  end

  @impl true
  def handle_event("clear_search", _params, socket), do: {:noreply, socket |> assign(:search_query, "") |> assign(:search_results, [])}

  @impl true
  def handle_event("toggle_show_archived", _params, socket), do: {:noreply, assign(socket, :show_archived, !socket.assigns.show_archived)}

  @impl true
  def handle_event("open_menu", %{"id" => id}, socket) do
    id = String.to_integer(id)
    next = if socket.assigns.show_menu_for == id, do: nil, else: id
    {:noreply, assign(socket, :show_menu_for, next)}
  end

  @impl true
  def handle_event("close_menu", _params, socket), do: {:noreply, assign(socket, :show_menu_for, nil)}

  @impl true
  def handle_event("toggle_mute", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.toggle_mute(id, user.id)
    conversations = Chat.list_conversations_for_user(user.id)
    {:noreply, socket |> assign(:conversations, conversations) |> assign(:show_menu_for, nil)}
  end

  @impl true
  def handle_event("toggle_pin", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.toggle_pin(id, user.id)
    conversations = Chat.list_conversations_for_user(user.id)
    {:noreply, socket |> assign(:conversations, conversations) |> assign(:show_menu_for, nil)}
  end

  @impl true
  def handle_event("toggle_archive", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.toggle_archive(id, user.id)
    conversations = Chat.list_conversations_for_user(user.id)
    active_id = socket.assigns.active_conversation && socket.assigns.active_conversation.id
    socket = if active_id == id, do: socket |> assign(:active_conversation, nil) |> assign(:messages, []) |> push_patch(to: ~p"/chat"), else: socket
    {:noreply, socket |> assign(:conversations, conversations) |> assign(:show_menu_for, nil)}
  end

  @impl true
  def handle_event("leave_group", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    case Chat.leave_group(id, user.id) do
      {:ok, _} ->
        conversations = Chat.list_conversations_for_user(user.id)
        {:noreply, socket |> assign(:conversations, conversations) |> assign(:active_conversation, nil) |> assign(:messages, []) |> assign(:show_menu_for, nil) |> push_patch(to: ~p"/chat") |> put_flash(:info, "You left the group")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not leave group")}
    end
  end

  @impl true
  def handle_event("block_user", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    case Chat.block_user(user.id, id) do
      {:ok, _} ->
        blocked_ids = Chat.list_blocked_ids(user.id)
        all_users = Chat.list_all_users(user.id)
        users = Enum.reject(all_users, &MapSet.member?(blocked_ids, &1.id))
        blocked_users = Enum.filter(all_users, &MapSet.member?(blocked_ids, &1.id))
        conversations = Chat.list_conversations_for_user(user.id)

        {:noreply, socket
         |> assign(:blocked_ids, blocked_ids)
         |> assign(:users, users)
         |> assign(:blocked_users, blocked_users)
         |> assign(:conversations, conversations)
         |> assign(:show_menu_for, nil)
         |> put_flash(:info, "User blocked")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not block user")}
    end
  end

  @impl true
  def handle_event("unblock_user", %{"id" => id}, socket) do
    id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.unblock_user(user.id, id)

    blocked_ids = Chat.list_blocked_ids(user.id)
    all_users = Chat.list_all_users(user.id)
    users = Enum.reject(all_users, &MapSet.member?(blocked_ids, &1.id))
    blocked_users = Enum.filter(all_users, &MapSet.member?(blocked_ids, &1.id))

    {:noreply, socket
     |> assign(:blocked_ids, blocked_ids)
     |> assign(:users, users)
     |> assign(:blocked_users, blocked_users)
     |> put_flash(:info, "User unblocked")}
  end

  @impl true
  def handle_event("toggle_star", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user
    if Chat.starred?(message_id, user.id), do: Chat.unstar_message(message_id, user.id), else: Chat.star_message(message_id, user.id)
    starred = Chat.starred_message_ids_for(user.id, Enum.map(socket.assigns.messages, & &1.id))
    {:noreply, assign(socket, :starred_message_ids, starred)}
  end

  @impl true
  def handle_event("open_forward", %{"id" => id}, socket), do: {:noreply, assign(socket, :forwarding_message_id, String.to_integer(id))}

  @impl true
  def handle_event("close_forward", _params, socket), do: {:noreply, assign(socket, :forwarding_message_id, nil)}

  @impl true
  def handle_event("forward_to", %{"conversation_id" => conv_id}, socket) do
    message_id = socket.assigns.forwarding_message_id
    user = socket.assigns.current_user
    conv_id = String.to_integer(conv_id)
    case Chat.forward_message(message_id, conv_id, user.id) do
      {:ok, new_message} ->
        target = Chat.get_conversation_with_participants!(conv_id)
        for participant <- target.users do
          Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:new_message, new_message})
        end
        {:noreply, socket |> assign(:forwarding_message_id, nil) |> put_flash(:info, "Message forwarded")}
      _ ->
        {:noreply, put_flash(socket, :error, "Could not forward message")}
    end
  end

  @impl true
  def handle_event("open_report", %{"id" => id}, socket), do: {:noreply, socket |> assign(:reporting_message_id, String.to_integer(id)) |> assign(:report_form, to_form(%{"reason" => "spam", "details" => ""}))}

  @impl true
  def handle_event("close_report", _params, socket), do: {:noreply, assign(socket, :reporting_message_id, nil)}

  @impl true
  def handle_event("validate_report", params, socket), do: {:noreply, assign(socket, :report_form, to_form(params))}

  @impl true
  def handle_event("submit_report", %{"reason" => reason, "details" => details}, socket) do
    message_id = socket.assigns.reporting_message_id
    user = socket.assigns.current_user
    message = Chat.get_message!(message_id)
    attrs = %{
      reported_user_id: message.user_id,
      message_id: message_id,
      conversation_id: message.conversation_id,
      reason: reason,
      details: String.trim(details)
    }
    case ViraChat.Reports.create_report(user.id, attrs) do
      {:ok, _} -> {:noreply, socket |> assign(:reporting_message_id, nil) |> put_flash(:info, "Report submitted. Thank you.")}
      _ -> {:noreply, put_flash(socket, :error, "Could not submit report")}
    end
  end

  @impl true
  def handle_event("open_starred", _params, socket), do: {:noreply, push_navigate(socket, to: ~p"/starred")}

  @impl true
  def handle_event("send_message", %{"content" => content}, socket) do
    content = String.trim(content)
    if is_nil(socket.assigns.active_conversation) do
      {:noreply, socket}
    else
      conversation = socket.assigns.active_conversation
      user = socket.assigns.current_user
      reply_to = socket.assigns.reply_to
      reply_to_id = if reply_to, do: reply_to.id, else: nil
      save_upload = fn socket, key, default_ext ->
        socket
        |> consume_uploaded_entries(key, fn %{path: path}, entry ->
          ext = case Path.extname(entry.client_name) do "" -> default_ext; e -> e end
          filename = "#{System.unique_integer([:positive])}#{ext}"
          dest = Path.join(["priv", "static", "uploads", filename])
          File.mkdir_p!(Path.dirname(dest))
          File.cp!(path, dest)
          {:ok, "/uploads/#{filename}"}
        end)
        |> List.first()
      end
      media_url = save_upload.(socket, :audio, ".webm") || save_upload.(socket, :image, ".jpg")
      if content == "" and is_nil(media_url) do
        {:noreply, socket}
      else
        {:ok, message} = Chat.create_message_with_media(conversation.id, user.id, content, media_url, reply_to_id)
        for participant <- conversation.users do
          Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:new_message, message})
        end
        mentioned =
          if Chat.has_everyone_mention?(content) do
            Enum.reject(conversation.users, &(&1.id == user.id))
          else
            Chat.extract_mentions(content, conversation.users) |> Enum.reject(&(&1.id == user.id))
          end
        for mentioned_user <- mentioned do
          Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{mentioned_user.id}", {:mentioned, conversation.id, user})
        end
        if url = LinkPreview.first_url(content) do
          Task.start(fn ->
            case LinkPreview.fetch(url) do
              nil -> :ok
              preview ->
                updated = Chat.attach_link_preview(message.id, preview)
                for p <- conversation.users do
                  Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{p.id}", {:message_updated, updated})
                end
            end
          end)
        end
        {:noreply, socket |> assign(:message_form, to_form(%{"content" => ""})) |> assign(:reply_to, nil)}
      end
    end
  end

  @impl true
  def handle_event("start_reply", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    message = Enum.find(socket.assigns.messages, fn m -> m.id == message_id end)
    if message, do: {:noreply, assign(socket, :reply_to, message)}, else: {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_reply", _params, socket), do: {:noreply, assign(socket, :reply_to, nil)}

  @impl true
  def handle_event("start_edit", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    message = Enum.find(socket.assigns.messages, fn m -> m.id == message_id end)
    if message && message.user_id == socket.assigns.current_user.id && !Chat.Message.deleted?(message) do
      {:noreply, socket |> assign(:editing_message_id, message_id) |> assign(:edit_form, to_form(%{"content" => message.content || ""}))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket), do: {:noreply, socket |> assign(:editing_message_id, nil) |> assign(:edit_form, nil)}

  @impl true
  def handle_event("save_edit", %{"content" => content}, socket) do
    message_id = socket.assigns.editing_message_id
    current_user = socket.assigns.current_user
    case Chat.edit_message(message_id, current_user.id, content) do
      {:ok, updated} ->
        for participant <- socket.assigns.active_conversation.users do
          Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:message_updated, updated})
        end
        {:noreply, socket |> assign(:editing_message_id, nil) |> assign(:edit_form, nil)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not edit message")}
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    current_user = socket.assigns.current_user
    case Chat.delete_message(message_id, current_user.id) do
      {:ok, updated} ->
        for participant <- socket.assigns.active_conversation.users do
          Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:message_updated, updated})
        end
        {:noreply, socket}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete message")}
    end
  end

  @impl true
  def handle_event("start_chat", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_user
    user_id = String.to_integer(user_id)
    if Chat.blocked_between?(current_user.id, user_id) do
      {:noreply, put_flash(socket, :error, "Cannot chat with this user")}
    else
      {:ok, conversation} = Chat.create_private_conversation(current_user.id, user_id)
      {:noreply, push_patch(socket, to: ~p"/chat/#{conversation.id}")}
    end
  end

  @impl true
  def handle_event("toggle_new_chat", _params, socket), do: {:noreply, socket |> assign(:show_new_chat, !socket.assigns.show_new_chat) |> assign(:show_new_group, false)}

  @impl true
  def handle_event("toggle_new_group", _params, socket), do: {:noreply, socket |> assign(:show_new_group, !socket.assigns.show_new_group) |> assign(:show_new_chat, false) |> assign(:group_title, "") |> assign(:group_members, [])}

  @impl true
  def handle_event("update_group_title", %{"value" => title}, socket), do: {:noreply, assign(socket, :group_title, title)}

  @impl true
  def handle_event("toggle_group_member", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    members = socket.assigns.group_members
    members = if user_id in members, do: List.delete(members, user_id), else: [user_id | members]
    {:noreply, assign(socket, :group_members, members)}
  end

  @impl true
  def handle_event("create_group", _params, socket) do
    title = String.trim(socket.assigns.group_title)
    members = socket.assigns.group_members
    creator_id = socket.assigns.current_user.id
    cond do
      title == "" -> {:noreply, put_flash(socket, :error, "Group needs a name")}
      members == [] -> {:noreply, put_flash(socket, :error, "Pick at least one member")}
      true ->
        {:ok, conversation} = Chat.create_group_conversation(title, creator_id, members)
        {:noreply, socket |> assign(:show_new_group, false) |> assign(:group_title, "") |> assign(:group_members, []) |> push_patch(to: ~p"/chat/#{conversation.id}")}
    end
  end

  @impl true
  def handle_event("typing", _params, socket) do
    if socket.assigns.active_conversation do
      user = socket.assigns.current_user
      conversation = socket.assigns.active_conversation
      for participant <- conversation.users, participant.id != user.id do
        Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:typing, conversation.id, user.id, User.display_name(user)})
      end
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}
  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket), do: {:noreply, cancel_upload(socket, :image, ref)}
  @impl true
  def handle_event("cancel-audio", %{"ref" => ref}, socket), do: {:noreply, cancel_upload(socket, :audio, ref)}
  @impl true
  def handle_event("voice_failed", %{"reason" => _reason}, socket), do: {:noreply, put_flash(socket, :error, "Could not start recording.")}
  @impl true
  def handle_event("push_subscribed", %{"subscription" => _}, socket), do: {:noreply, socket |> assign(:push_enabled, true) |> put_flash(:info, "Notifications enabled")}
  @impl true
  def handle_event("push_failed", %{"reason" => _}, socket), do: {:noreply, put_flash(socket, :error, "Could not enable notifications")}
  @impl true
  def handle_event("close_conversation", _params, socket), do: {:noreply, socket |> assign(:active_conversation, nil) |> assign(:messages, []) |> push_patch(to: ~p"/chat")}

  @impl true
  def handle_event("react", %{"id" => id, "emoji" => emoji}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user
    Chat.toggle_reaction(message_id, user.id, emoji)
    updated = Chat.reload_message(message_id)
    for participant <- socket.assigns.active_conversation.users do
      Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:message_updated, updated})
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("react_from_menu", params, socket), do: handle_event("react", params, socket)

  # --- handle_info ---
  @impl true
  def handle_info({:group_updated, conv_id}, socket) do
    active = socket.assigns.active_conversation
    socket =
      if active && active.id == conv_id do
        conversation = Chat.get_conversation_with_participants!(conv_id)
        conversations = Chat.list_conversations_for_user(socket.assigns.current_user.id)
        socket
        |> assign(:active_conversation, conversation)
        |> assign(:conversations, conversations)
        |> assign(:participants, Chat.list_participants_with_roles(conv_id))
        |> assign(:group_title_form, to_form(%{"title" => conversation.title || ""}))
      else
        socket
      end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:mentioned, conversation_id, from_user}, socket) do
    active = socket.assigns.active_conversation
    muted = Chat.muted?(conversation_id, socket.assigns.current_user.id)
    socket =
      cond do
        muted -> socket
        active && active.id == conversation_id -> socket
        true -> socket |> push_event("play_sound", %{kind: "mention"}) |> put_flash(:info, "#{User.display_name(from_user)} mentioned you")
      end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing, conversation_id, user_id, name}, socket) do
    active = socket.assigns.active_conversation
    if active && active.id == conversation_id do
      typing = socket.assigns.typing_users
      typing = if Enum.any?(typing, fn u -> u.id == user_id end), do: typing, else: typing ++ [%{id: user_id, name: name}]
      Process.send_after(self(), {:clear_typing, user_id}, 3000)
      {:noreply, assign(socket, :typing_users, typing)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:clear_typing, user_id}, socket) do
    typing = Enum.reject(socket.assigns.typing_users, fn u -> u.id == user_id end)
    {:noreply, assign(socket, :typing_users, typing)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    active = socket.assigns.active_conversation
    current_user = socket.assigns.current_user
    conversations = Chat.list_conversations_for_user(current_user.id)
    muted = Chat.muted?(message.conversation_id, current_user.id)

    if message.user_id != current_user.id do
      Chat.mark_conversation_delivered(message.conversation_id, current_user.id)
      conversation = Chat.get_conversation_with_participants!(message.conversation_id)
      for participant <- conversation.users, participant.id != current_user.id do
        Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:conversation_delivered, message.conversation_id, current_user.id})
      end
    end

    socket =
      if active && message.conversation_id == active.id do
        if message.user_id != current_user.id do
          Chat.mark_conversation_read(active.id, current_user.id)
          for participant <- active.users, participant.id != current_user.id do
            Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:conversation_read, active.id, current_user.id})
          end
          if muted, do: socket, else: push_event(socket, "play_sound", %{kind: "message"})
        else
          socket
        end
        |> then(fn s -> assign(s, :messages, s.assigns.messages ++ [message]) end)
      else
        unread_counts =
          if message.user_id != current_user.id do
            Map.update(socket.assigns.unread_counts, message.conversation_id, 1, &(&1 + 1))
          else
            socket.assigns.unread_counts
          end
        socket =
          if message.user_id != current_user.id && !muted do
            push_event(socket, "play_sound", %{kind: "message"})
          else
            socket
          end
        assign(socket, :unread_counts, unread_counts)
      end
    {:noreply, assign(socket, :conversations, conversations)}
  end

  @impl true
  def handle_info({:message_updated, updated}, socket) do
    active = socket.assigns.active_conversation
    socket =
      if active && active.id == updated.conversation_id do
        messages =
          Enum.map(socket.assigns.messages, fn m ->
            m = if m.id == updated.id, do: updated, else: m
            if m.reply_to_id == updated.id, do: %{m | reply_to: updated}, else: m
          end)
        assign(socket, :messages, messages)
      else
        socket
      end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_read, conversation_id, user_id}, socket) do
    active = socket.assigns.active_conversation
    socket =
      if active && active.id == conversation_id do
        reader_last_read = Chat.last_read_at_for(conversation_id, user_id)
        readers = Map.put(socket.assigns.readers, user_id, reader_last_read)
        assign(socket, :readers, readers)
      else
        socket
      end
    {:noreply, socket}
  end

  @impl true
  def handle_info({:conversation_delivered, conversation_id, user_id}, socket) do
    active = socket.assigns.active_conversation
    socket =
      if active && active.id == conversation_id do
        delivered_at = Chat.delivered_at_for(conversation_id, user_id)
        delivereds = Map.put(socket.assigns.delivereds, user_id, delivered_at)
        assign(socket, :delivereds, delivereds)
      else
        socket
      end
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"} = msg, socket) do
    leaves = msg.payload[:leaves] || %{}
    for {user_id_str, _} <- leaves do
      case Integer.parse(user_id_str) do
        {user_id, _} -> Chat.touch_last_seen(user_id)
        _ -> :ok
      end
    end
    online = list_online_users()
    socket =
      case socket.assigns.active_conversation do
        nil -> socket
        conv ->
          reloaded = Chat.get_conversation_with_participants!(conv.id)
          assign(socket, :active_conversation, reloaded)
      end
    {:noreply, assign(socket, :online_users, online)}
  end

  # --- Helpers ---
  defp broadcast_group_update(conv_id) do
    conversation = Chat.get_conversation_with_participants!(conv_id)
    for participant <- conversation.users do
      Phoenix.PubSub.broadcast(ViraChat.PubSub, "user:#{participant.id}", {:group_updated, conv_id})
    end
  end

  defp list_online_users do
    ViraChatWeb.Presence.list("online_users") |> Map.keys() |> Enum.map(&String.to_integer/1)
  end

  defp conversation_title(conversation, current_user) do
    case conversation.type do
      "group" -> conversation.title || "Group Chat"
      "private" ->
        other = Enum.find(conversation.users, fn u -> u.id != current_user.id end)
        (other && User.display_name(other)) || "Chat"
    end
  end

  defp conversation_avatar(conversation, current_user) do
    case conversation.type do
      "group" -> conversation.avatar_url
      "private" ->
        other = Enum.find(conversation.users, fn u -> u.id != current_user.id end)
        other && other.avatar_url
    end
  end

  defp message_seen?(message, conversation, current_user, readers) do
    if message.user_id != current_user.id do
      false
    else
      other_ids = Enum.map(conversation.users, & &1.id) -- [current_user.id]
      if other_ids == [] do
        false
      else
        Enum.all?(other_ids, fn oid ->
          case Map.get(readers, oid) do
            nil -> false
            %DateTime{} = dt -> NaiveDateTime.compare(DateTime.to_naive(dt), message.inserted_at) != :lt
            %NaiveDateTime{} = ndt -> NaiveDateTime.compare(ndt, message.inserted_at) != :lt
          end
        end)
      end
    end
  end

  defp message_delivered?(message, conversation, current_user, delivereds) do
    if message.user_id != current_user.id do
      false
    else
      other_ids = Enum.map(conversation.users, & &1.id) -- [current_user.id]
      if other_ids == [] do
        false
      else
        Enum.all?(other_ids, fn oid ->
          case Map.get(delivereds, oid) do
            nil -> false
            %DateTime{} = dt -> NaiveDateTime.compare(DateTime.to_naive(dt), message.inserted_at) != :lt
            %NaiveDateTime{} = ndt -> NaiveDateTime.compare(ndt, message.inserted_at) != :lt
          end
        end)
      end
    end
  end

  defp highlight(text, query) when is_binary(text) and is_binary(query) and query != "" do
    safe_text = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()
    pattern = Regex.compile!("(?i)" <> Regex.escape(query))
    Regex.replace(pattern, safe_text, fn m ->
      "<mark class=\"bg-yellow-200 dark:bg-yellow-700/60 text-gray-900 dark:text-white rounded px-0.5\">#{m}</mark>"
    end)
    |> Phoenix.HTML.raw()
  end

  defp highlight(text, _query), do: text

  defp audio_url?(url) when is_binary(url) do
    ext = url |> Path.extname() |> String.downcase()
    ext in [".webm", ".ogg", ".mp3", ".m4a", ".wav"]
  end

  defp audio_url?(_), do: false

  defp reaction_groups(reactions, current_user) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, list} ->
      %{
        emoji: emoji,
        count: length(list),
        me?: Enum.any?(list, fn r -> r.user_id == current_user.id end),
        users: Enum.map(list, &ViraChat.Accounts.User.display_name(&1.user))
      }
    end)
    |> Enum.sort_by(fn g -> {(if g.me?, do: 0, else: 1), -g.count} end)
  end

  defp render_with_mentions(content, participants, is_mine) when is_binary(content) do
    safe = Phoenix.HTML.html_escape(content) |> Phoenix.HTML.safe_to_string()
    names =
      (Enum.flat_map(participants, fn u ->
         [User.display_name(u), u.email |> String.split("@") |> List.first()]
       end)
       |> Enum.reject(&is_nil/1)
       |> Enum.uniq()) ++ ["here", "everyone"]
    if names == [] do
      content
    else
      pattern = names |> Enum.map(&Regex.escape/1) |> Enum.join("|")
      regex = Regex.compile!("@(#{pattern})(?=\\s|$|[[:punct:]])", "iu")
      highlight_class =
        if is_mine,
          do: "bg-indigo-400/60 text-white rounded px-1 font-medium",
          else: "bg-yellow-200 dark:bg-yellow-700/60 text-slate-900 dark:text-white rounded px-1 font-medium"
      Regex.replace(regex, safe, fn match -> "<span class=\"#{highlight_class}\">#{match}</span>" end)
      |> Phoenix.HTML.raw()
    end
  end

  defp render_with_mentions(content, _participants, _is_mine), do: content

  defp time_ago(dt) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    dt_as_dt = case dt do
      %DateTime{} = d -> d
      %NaiveDateTime{} = nd -> DateTime.from_naive!(nd, "Etc/UTC")
    end
    diff = DateTime.diff(now, dt_as_dt, :second)
    cond do
      diff < 0 -> "just now"
      diff < 10 -> "just now"
      diff < 60 -> "#{diff}s ago"
      diff < 3_600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3_600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(dt_as_dt, "%b %d, %Y")
    end
  end

  defp last_seen_text(nil), do: "Offline"
  defp last_seen_text(dt) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    dt_as_dt = case dt do
      %DateTime{} = d -> d
      %NaiveDateTime{} = nd -> DateTime.from_naive!(nd, "Etc/UTC")
    end
    diff = DateTime.diff(now, dt_as_dt, :second)
    cond do
      diff < 0 -> "Last seen just now"
      diff < 60 -> "Last seen just now"
      diff < 3600 -> "Last seen #{div(diff, 60)}m ago"
      diff < 86_400 -> "Last seen #{div(diff, 3600)}h ago"
      diff < 604_800 -> "Last seen #{div(diff, 86_400)}d ago"
      true -> "Last seen #{Calendar.strftime(dt_as_dt, "%b %d")}"
    end
  end

  defp error_to_string(:too_large), do: "File is too large (Max 10MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type. Please use JPG, PNG, or WEBP."
  defp error_to_string(:external), do: "External upload failed"
  defp error_to_string(:max_entries), do: "Too many files selected"
  defp error_to_string(err), do: inspect(err)
end
