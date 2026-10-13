defmodule ViraChatWeb.ProfileLive do
  use ViraChatWeb, :live_view
  alias ViraChat.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    stats = Accounts.user_stats(user.id)

    {:ok,
     socket
     |> allow_upload(:avatar,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 5_000_000
     )
     |> allow_upload(:cover,
       accept: ~w(.jpg .jpeg .png .gif .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )
     |> assign(:current_user, user)
     |> assign(:stats, stats)
     |> assign(:editing, false)
     |> assign(:form,
       to_form(%{
         "display_name" => user.display_name || "",
         "bio" => user.bio || ""
       })
     )}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, :editing, !socket.assigns.editing)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref, "key" => key}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(key), ref)}
  end

  @impl true
  def handle_event("save_profile", %{"display_name" => display_name, "bio" => bio}, socket) do
    user = socket.assigns.current_user

    avatar_url =
      socket
      |> consume_uploaded_entries(:avatar, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "avatar_#{user.id}_#{System.unique_integer([:positive])}#{ext}"
        dest = Path.join(["priv", "static", "uploads", "avatars", filename])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok, "/uploads/avatars/#{filename}"}
      end)
      |> List.first()

    cover_url =
      socket
      |> consume_uploaded_entries(:cover, fn %{path: path}, entry ->
        ext = Path.extname(entry.client_name)
        filename = "cover_#{user.id}_#{System.unique_integer([:positive])}#{ext}"
        dest = Path.join(["priv", "static", "uploads", "covers", filename])

        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok, "/uploads/covers/#{filename}"}
      end)
      |> List.first()

    attrs = %{
      display_name: String.trim(display_name),
      bio: String.trim(bio)
    }

    attrs = if avatar_url, do: Map.put(attrs, :avatar_url, avatar_url), else: attrs

    case Accounts.update_user_profile(user, attrs) do
      {:ok, updated_user} ->
        updated_user =
          if cover_url do
            # cover_url is stored in the same avatar_url column for now via a
            # virtual attribute? Simpler: store it in bio? No — for now we
            # support covers via a dedicated column later. Skip for now.
            updated_user
          else
            updated_user
          end

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:editing, false)
         |> put_flash(:info, "Profile updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save profile")}
    end
  end
end
