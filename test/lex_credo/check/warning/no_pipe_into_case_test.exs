defmodule LexCredo.Check.Warning.NoPipeIntoCaseTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoPipeIntoCase

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NoPipeIntoCase.run([])
  end

  test "flags a direct pipe into case" do
    source = """
    defmodule M do
      def f(x) do
        x
        |> bar()
        |> case do
          {:ok, v} -> v
          _error -> nil
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Do not pipe into `case`"
    assert issue.trigger == "|>"
  end

  test "flags a single-step pipe into case" do
    source = """
    defmodule M do
      def f(x) do
        fetch(x)
        |> case do
          {:ok, v} -> v
          _err -> :error
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "|>"
  end

  test "does not flag a normal case expression" do
    source = """
    defmodule M do
      def f(x) do
        result = bar(x)

        case result do
          {:ok, v} -> v
          _error -> nil
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a pipe chain that does not end in case" do
    source = """
    defmodule M do
      def f(x) do
        x
        |> foo()
        |> bar()
      end
    end
    """

    assert run(source) == []
  end
end
