defmodule ViraChatWeb.AdminLive.Reports do
  use ViraChatWeb, :live_view
  import ViraChatWeb.AdminComponents
  alias ViraChat.Reports
  alias ViraChat.Admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_user, socket.assigns.current_scope.user)
     |> assign(:filter, "pending")
     |> assign(:reports, Reports.list_reports(status: "pending"))}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    reports = Reports.list_reports(status: if(status == "", do: nil, else: status))
    {:noreply, socket |> assign(:filter, status) |> assign(:reports, reports)}
  end

  @impl true
  def handle_event("resolve", %{"id" => id}, socket) do
    report_id = String.to_integer(id)
    admin = socket.assigns.current_user

    case Reports.resolve_report(report_id, admin.id, "resolved") do
      {:ok, _} ->
        Admin.log_action(admin, nil, "resolve_report", %{"report_id" => report_id, "status" => "resolved"})
        reports = Reports.list_reports(status: if(socket.assigns.filter == "", do: nil, else: socket.assigns.filter))

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> put_flash(:info, "Report marked resolved")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not resolve report")}
    end
  end

  @impl true
  def handle_event("dismiss", %{"id" => id}, socket) do
    report_id = String.to_integer(id)
    admin = socket.assigns.current_user

    case Reports.resolve_report(report_id, admin.id, "dismissed") do
      {:ok, _} ->
        Admin.log_action(admin, nil, "dismiss_report", %{"report_id" => report_id, "status" => "dismissed"})
        reports = Reports.list_reports(status: if(socket.assigns.filter == "", do: nil, else: socket.assigns.filter))

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> put_flash(:info, "Report dismissed")}

      _ ->
        {:noreply, put_flash(socket, :error, "Could not dismiss report")}
    end
  end

  @impl true
  def handle_event("ban_reported_user", %{"id" => id}, socket) do
    report_id = String.to_integer(id)
    admin = socket.assigns.current_user
    report = Enum.find(socket.assigns.reports, fn r -> r.id == report_id end)

    cond do
      is_nil(report) -> {:noreply, put_flash(socket, :error, "Report not found")}
      is_nil(report.reported_user) -> {:noreply, put_flash(socket, :error, "Reported user no longer exists")}
      report.reported_user.id == admin.id -> {:noreply, put_flash(socket, :error, "You cannot ban yourself")}
      true ->
        Admin.ban_user(report.reported_user, admin)
        Reports.resolve_report(report_id, admin.id, "resolved")
        reports = Reports.list_reports(status: if(socket.assigns.filter == "", do: nil, else: socket.assigns.filter))

        {:noreply,
         socket
         |> assign(:reports, reports)
         |> put_flash(:info, "User banned and report resolved")}
    end
  end
end
