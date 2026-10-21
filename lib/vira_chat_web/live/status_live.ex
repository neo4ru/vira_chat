defmodule ViraChatWeb.StatusLive do
  use ViraChatWeb, :live_view

  alias ViraChat.Statuses
  alias ViraChat.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    if connected?(socket), do: Statuses.purge_expired()

    {:ok,
     socket
     |> allow_upload(:status_image,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 8_000_000
     )
     |> assign(:current_user, user)
     |> assign(:show_new, false)
     |> assign(:viewing, nil)
     |> assign(:form, to_form(%{"content" => "", "background" => "#6338F6"}))
     |> assign(:statuses, Statuses.list_active())}
  end

  @impl true
  def handle_event("toggle_new", _params, socket) do
    {:noreply, assign(socket, :show_new, !socket.assigns.show_new)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :status_image, ref)}
  end

  @impl true
  def handle_event("create_status", params, socket) do
    user = socket.assigns.current_user
    content = String.trim(params["content"] || "")
    background = params["background"] || "#6338F6"

    media_url =
      socket
      |> consume_uploaded_entries(:status_image, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "status_#{user.id}_#{System.unique_integer([:positive])}#{ext}"
        dest = Path.join(["priv", "static", "uploads", "statuses", filename])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok, "/uploads/statuses/#{filename}"}
      end)
      |> List.first()

    if content == "" && is_nil(media_url) do
      {:noreply, put_flash(socket, :error, "Add some text or an image to your status")}
    else
      case Statuses.create(user.id, %{
             content: if(content == "", do: nil, else: content),
             media_url: media_url,
             background: background
           }) do
        {:ok, _status} ->
          {:noreply,
           socket
           |> assign(:statuses, Statuses.list_active())
           |> assign(:form, to_form(%{"content" => "", "background" => "#6338F6"}))
           |> assign(:show_new, false)
           |> put_flash(:info, "Status shared — it disappears in 24 hours")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not post your status")}
      end
    end
  end

  @impl true
  def handle_event("view_status", %{"id" => id}, socket) do
    case Statuses.get_status(id) do
      nil ->
        {:noreply,
         socket
         |> assign(:statuses, Statuses.list_active())
         |> put_flash(:error, "This status has expired")}

      status ->
        if status.user_id != socket.assigns.current_user.id do
          Statuses.mark_viewed(status.id, socket.assigns.current_user.id)
        end

        {:noreply, assign(socket, :viewing, status)}
    end
  end

  @impl true
  def handle_event("close_viewer", _params, socket) do
    {:noreply, socket |> assign(:viewing, nil) |> assign(:statuses, Statuses.list_active())}
  end

  @impl true
  def handle_event("delete_status", %{"id" => id}, socket) do
    case Statuses.delete(id, socket.assigns.current_user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:viewing, nil)
         |> assign(:statuses, Statuses.list_active())
         |> put_flash(:info, "Status deleted")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not delete status")}
    end
  end

  # --- Template helpers ---

  defp mine(statuses, user), do: Enum.filter(statuses, &(&1.user_id == user.id))
  defp others(statuses, user), do: Enum.reject(statuses, &(&1.user_id == user.id))

  defp grouped_by_user(statuses) do
    statuses
    |> Enum.group_by(& &1.user_id)
    |> Enum.map(fn {_id, list} -> Enum.sort_by(list, & &1.inserted_at, {:desc, NaiveDateTime}) end)
    |> Enum.sort_by(fn [first | _] -> first.inserted_at end, {:desc, NaiveDateTime})
  end

  defp age_label(inserted_at) do
    minutes = NaiveDateTime.diff(NaiveDateTime.utc_now(), inserted_at, :minute)

    cond do
      minutes < 1 -> "Just now"
      minutes < 60 -> "#{minutes}m ago"
      true -> "#{div(minutes, 60)}h ago"
    end
  end

  defp status_preview(status) do
    cond do
      is_binary(status.media_url) and status.media_url != "" -> nil
      is_binary(status.content) and status.content != "" -> status.content
      true -> ""
    end
  end

  defp display_name(nil), do: "Unknown"
  defp display_name(user), do: User.display_name(user)
end
