defmodule ViraChatWeb.LiveHelpers do
  @doc """
  Takes a list of {message, opts} error tuples and returns a plain string.
  """
  def translate_errors([]), do: ""

  def translate_errors(errors) do
    errors
    |> Enum.map(fn {msg, _opts} -> msg end)
    |> Enum.join(", ")
  end
end
