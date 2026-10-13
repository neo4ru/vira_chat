defmodule ViraChatWeb.ErrorJSONTest do
  use ViraChatWeb.ConnCase, async: true

  test "renders 404" do
    assert ViraChatWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ViraChatWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
