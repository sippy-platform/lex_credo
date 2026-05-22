defmodule LexCredo.CheckHelpers do
  @moduledoc """
  Shared utility functions for LexCredo checks.
  """

  alias Credo.Check.Params
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

  @doc """
  Returns `true` when the file should be skipped because it is a test file
  and the `:exclude_test_files` param resolves to `true` for the given check module.

  Used by all LexCredo checks to implement the `exclude_test_files` parameter
  uniformly.

  ## Examples

      # Typical use inside a check's run/2:
      def run(%SourceFile{} = source_file, params) do
        if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
          []
        else
          # ... run the check
        end
      end

  """
  @spec skip_for_test_file?(SourceFile.t(), keyword(), module()) :: boolean()
  def skip_for_test_file?(%SourceFile{} = source_file, params, module) do
    Params.get(params, :exclude_test_files, module) and test_file?(source_file)
  end
end
