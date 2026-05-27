defmodule LexCredo.Check.Readability.DocExamplesSectionTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Readability.DocExamplesSection

  defp run(source, params \\ []) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> DocExamplesSection.run(params)
  end

  # ---------------------------------------------------------------------------
  # Basic flagging
  # ---------------------------------------------------------------------------

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
    assert issue.message =~ "foo/0"
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
    assert issue.message =~ "value/0"
  end

  test "includes arity in the issue message" do
    source = """
    defmodule M do
      @doc "Adds two numbers."
      def add(a, b), do: a + b
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "add/2"
  end

  test "handles a function with a guard in its head" do
    source = """
    defmodule M do
      @doc "Returns x when positive."
      def pos(x) when x > 0, do: x
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "pos/1"
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

  # ---------------------------------------------------------------------------
  # Not flagged — doc has Examples
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Not flagged — @doc false / nil / moduledoc
  # ---------------------------------------------------------------------------

  test "does not flag @doc false" do
    source = """
    defmodule M do
      @doc false
      def hidden, do: :hidden
    end
    """

    assert run(source) == []
  end

  test "does not flag @doc nil" do
    source = """
    defmodule M do
      @doc nil
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

  # ---------------------------------------------------------------------------
  # Not flagged — skip_def_types (default behaviour)
  # ---------------------------------------------------------------------------

  test "does not flag @doc before defmacro (skipped by default)" do
    source = """
    defmodule M do
      @doc \"\"\"
      A macro that injects code.
      \"\"\"
      defmacro my_macro(ast), do: ast
    end
    """

    assert run(source) == []
  end

  test "does not flag @doc before defmacrop (skipped by default)" do
    source = """
    defmodule M do
      @doc \"\"\"
      A private macro.
      \"\"\"
      defmacrop helper(ast), do: ast
    end
    """

    assert run(source) == []
  end

  test "does not flag @doc before defp (skipped by default)" do
    source = """
    defmodule M do
      @doc \"\"\"
      A private function — unusual but valid.
      \"\"\"
      defp priv(x), do: x
    end
    """

    assert run(source) == []
  end

  test "does not flag @doc before defguard (skipped by default)" do
    source = """
    defmodule M do
      @doc "Guards for positive integers."
      defguard is_positive(x) when is_integer(x) and x > 0
    end
    """

    assert run(source) == []
  end

  test "does not flag @doc before defdelegate (skipped by default)" do
    source = """
    defmodule M do
      @doc "Delegates to Enum.map/2."
      defdelegate map(list, fun), to: Enum
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Configuring skip_def_types
  # ---------------------------------------------------------------------------

  test "flags @doc before defmacro when :defmacro is removed from skip_def_types" do
    source = """
    defmodule M do
      @doc \"\"\"
      A macro without examples.
      \"\"\"
      defmacro my_macro(ast), do: ast
    end
    """

    assert [issue] = run(source, skip_def_types: [:defp])
    assert issue.message =~ "my_macro/1"
  end

  test "does not flag @doc before def when :def is added to skip_def_types" do
    source = """
    defmodule M do
      @doc "A public function."
      def foo, do: :ok
    end
    """

    assert run(source, skip_def_types: [:def]) == []
  end

  # ---------------------------------------------------------------------------
  # Test-file exclusion
  # ---------------------------------------------------------------------------

  test "does not flag a test file when exclude_test_files: true" do
    source = """
    defmodule MyTest do
      @doc "No examples here."
      def helper, do: :ok
    end
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/support/helpers.ex")
      |> DocExamplesSection.run(exclude_test_files: true)

    assert issues == []
  end
end
