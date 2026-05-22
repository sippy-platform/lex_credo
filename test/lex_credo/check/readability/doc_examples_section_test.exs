defmodule LexCredo.Check.Readability.DocExamplesSectionTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Readability.DocExamplesSection

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> DocExamplesSection.run([])
  end

  test "flags a @doc string without an Examples section" do
    source = """
    defmodule M do
      @doc \"\"\"
      Does something useful.
      \"\"\"
      def foo, do: :ok
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "## Examples"
    assert issue.trigger == "@doc"
  end

  test "flags a single-line @doc string without Examples" do
    source = """
    defmodule M do
      @doc "Returns the value."
      def value, do: 42
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "## Examples"
  end

  test "does not flag a @doc string that contains ## Examples" do
    source = """
    defmodule M do
      @doc \"\"\"
      Does something.

      ## Examples

          iex> M.foo()
          :ok

      \"\"\"
      def foo, do: :ok
    end
    """

    assert run(source) == []
  end

  test "does not flag @doc false" do
    source = """
    defmodule M do
      @doc false
      def hidden, do: :hidden
    end
    """

    assert run(source) == []
  end

  test "does not flag @moduledoc" do
    source = """
    defmodule M do
      @moduledoc \"\"\"
      This is a module without examples.
      \"\"\"
    end
    """

    assert run(source) == []
  end

  test "flags multiple @doc strings missing Examples in the same module" do
    source = """
    defmodule M do
      @doc "First function."
      def first, do: 1

      @doc "Second function."
      def second, do: 2
    end
    """

    assert [_issue1, _issue2] = run(source)
  end
end
