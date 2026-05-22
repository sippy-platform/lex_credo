defmodule LexCredo.Check.Warning.NoComplexWithElseTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoComplexWithElse

  defp run(source, params \\ []) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NoComplexWithElse.run(params)
  end

  test "flags a with expression with 2 else clauses" do
    source = """
    defmodule M do
      def f(data) do
        with {:ok, a} <- step_a(data),
             {:ok, b} <- step_b(a) do
          {a, b}
        else
          {:error, :not_found} -> {:error, :not_found}
          {:error, :forbidden} -> {:error, :forbidden}
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "complex `else`"
    assert issue.trigger == "with"
  end

  test "flags a with expression with 3 else clauses" do
    source = """
    defmodule M do
      def f(data) do
        with {:ok, a} <- step_a(data),
             {:ok, b} <- step_b(a) do
          {a, b}
        else
          :error -> :error
          {:error, :a} -> {:error, :a}
          {:error, :b} -> {:error, :b}
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "3 clauses"
  end

  test "does not flag a with expression with 1 else clause" do
    source = """
    defmodule M do
      def f(data) do
        with {:ok, a} <- step_a(data) do
          a
        else
          _error -> :error
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a with expression with no else block" do
    source = """
    defmodule M do
      def f(data) do
        with {:ok, a} <- step_a(data),
             {:ok, b} <- step_b(a) do
          {a, b}
        end
      end
    end
    """

    assert run(source) == []
  end

  test "allows more clauses when max_else_clauses is configured higher" do
    source = """
    defmodule M do
      def f(data) do
        with {:ok, a} <- step_a(data),
             {:ok, b} <- step_b(a) do
          {a, b}
        else
          {:error, :a} -> :a
          {:error, :b} -> :b
          {:error, :c} -> :c
        end
      end
    end
    """

    assert run(source, max_else_clauses: 3) == []
  end
end
