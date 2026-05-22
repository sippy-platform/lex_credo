defmodule LexCredo.CheckHelpers do
  @moduledoc """
  Shared utility functions for LexCredo checks.
  """

  alias Credo.SourceFile

  @doc """
  Returns `true` if the source file is a test file (path contains `/test/` or
  filename ends with `_test.exs`).

  ## Examples

      iex> LexCredo.CheckHelpers.test_file?(%Credo.SourceFile{filename: "test/my_test.exs"})
      true

      iex> LexCredo.CheckHelpers.test_file?(%Credo.SourceFile{filename: "test/support/factory.ex"})
      true

      iex> LexCredo.CheckHelpers.test_file?(%Credo.SourceFile{filename: "lib/my_module.ex"})
      false

  """
  @spec test_file?(SourceFile.t()) :: boolean()
  def test_file?(%SourceFile{filename: filename}) do
    String.ends_with?(filename, "_test.exs") or
      String.contains?(filename, "/test/") or
      String.starts_with?(filename, "test/")
  end
end
