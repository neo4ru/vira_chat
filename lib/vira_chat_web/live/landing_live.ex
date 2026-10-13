defmodule ViraChatWeb.LandingLive do
  use ViraChatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "ViraChat — Modern messaging for everyone")}
  end
end
