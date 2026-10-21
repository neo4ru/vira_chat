defmodule ViraChatWeb.PageControllerTest do
  use ViraChatWeb.ConnCase

  test "GET / renders the landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "ViraChat"
    assert html =~ "Chat. Connect."
  end
end
