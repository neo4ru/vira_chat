defmodule ViraChatWeb.ProfileLive do
  use ViraChatWeb, :live_view
  alias ViraChat.Accounts

  @countries ~w(India United States Canada United Kingdom Australia Germany France
                Netherlands Singapore United Arab Emirates Nepal Sri Lanka Pakistan
                Bangladesh Brazil Japan China South Africa Nigeria Kenya New Zealand Other)

  @dial_codes [
    {"+91", "IN +91"},
    {"+1", "US +1"},
    {"+44", "UK +44"},
    {"+61", "AU +61"},
    {"+49", "DE +49"},
    {"+33", "FR +33"},
    {"+31", "NL +31"},
    {"+65", "SG +65"},
    {"+971", "AE +971"},
    {"+977", "NP +977"},
    {"+94", "LK +94"},
    {"+92", "PK +92"},
    {"+880", "BD +880"},
    {"+55", "BR +55"},
    {"+81", "JP +81"},
    {"+86", "CN +86"},
    {"+27", "ZA +27"},
    {"+234", "NG +234"},
    {"+254", "KE +254"},
    {"+64", "NZ +64"}
  ]

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
     |> assign(:countries, @countries)
     |> assign(:dial_codes, @dial_codes)
     |> assign(:editing, false)
     |> assign(:show_qr, false)
     |> assign(:qr_tab, "mine")
     |> assign(:profile_url, url(~p"/chat?add=#{user.id}"))
     |> assign(
       :form,
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
  def handle_event("toggle_qr", _params, socket) do
    show = !socket.assigns.show_qr

    {:noreply,
     socket
     |> assign(:show_qr, show)
     |> assign(:qr_tab, "mine")}
  end

  @impl true
  def handle_event("qr_tab", %{"tab" => tab}, socket) when tab in ["mine", "scan"] do
    {:noreply, assign(socket, :qr_tab, tab)}
  end

  @impl true
  def handle_event("close_qr", _params, socket) do
    {:noreply, assign(socket, :show_qr, false)}
  end

  @impl true
  def handle_event("toggle_status", %{"field" => field}, socket)
      when field in ["active", "friends"] do
    user = socket.assigns.current_user

    attrs =
      case field do
        "active" -> %{active_status: !user.active_status}
        "friends" -> %{friends_status: !user.friends_status}
      end

    case Accounts.update_user_profile(user, attrs) do
      {:ok, updated} -> {:noreply, assign(socket, :current_user, updated)}
      _ -> {:noreply, put_flash(socket, :error, "Could not update status")}
    end
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
  def handle_event(
        "save_profile",
        %{"display_name" => display_name, "bio" => bio} = params,
        socket
      ) do
    user = socket.assigns.current_user
    phone = blank_to_nil(params["phone"])
    country = blank_to_nil(params["country"])
    phone_country_code = if phone, do: blank_to_nil(params["phone_country_code"]), else: nil

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
      bio: String.trim(bio),
      phone: phone,
      phone_country_code: phone_country_code,
      country: country,
      facebook: blank_to_nil(params["facebook"]),
      instagram: blank_to_nil(params["instagram"]),
      linkedin: blank_to_nil(params["linkedin"])
    }

    attrs = if avatar_url, do: Map.put(attrs, :avatar_url, avatar_url), else: attrs
    attrs = if cover_url, do: Map.put(attrs, :cover_url, cover_url), else: attrs

    case Accounts.update_user_profile(user, attrs) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:editing, false)
         |> put_flash(:info, "Profile updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save profile")}
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
