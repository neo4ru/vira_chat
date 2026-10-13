defmodule ViraChatWeb.PageController do
  use ViraChatWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
