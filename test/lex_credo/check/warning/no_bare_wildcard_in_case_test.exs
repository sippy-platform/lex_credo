defmodule LexCredo.Check.Warning.NoBareWildcardInCaseTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoBareWildcardInCase

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NoBareWildcardInCase.run([])
  end

  test "flags bare _ catch-all when case has {:ok, _} clause" do
    source = """
    defmodule M do
      def f(x) do
        case some_function(x) do
          {:ok, value} -> value
          _ -> nil
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "named catch-all"
    assert issue.trigger == "_"
  end

  test "flags bare _ catch-all when case has {:error, _} clause" do
    source = """
    defmodule M do
      def f(x) do
        case call(x) do
          {:error, reason} -> {:error, reason}
          _ -> :ok
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "_"
  end

  test "flags bare _ with a 3-element {:ok, _, _} pattern present" do
    source = """
    defmodule M do
      def f(x) do
        case call(x) do
          {:ok, a, b} -> {a, b}
          _ -> nil
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "_"
  end

  test "does not flag a named catch-all _error" do
    source = """
    defmodule M do
      def f(x) do
        case some_function(x) do
          {:ok, value} -> value
          _error -> nil
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a fully explicit pattern match" do
    source = """
    defmodule M do
      def f(x) do
        case some_function(x) do
          {:ok, value} -> value
          {:error, reason} -> raise inspect(reason)
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag bare _ in a case with no result-tuple patterns" do
    source = """
    defmodule M do
      def f(x) do
        case x do
          :foo -> 1
          :bar -> 2
          _ -> 3
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag bare _ in a case matching only on plain atoms" do
    source = """
    defmodule M do
      def classify(status) do
        case status do
          :active -> "active"
          :inactive -> "inactive"
          _ -> "unknown"
        end
      end
    end
    """

    assert run(source) == []
  end

  test "flags bare _ with guarded clause present" do
    source = """
    defmodule M do
      def f(x) do
        case call(x) do
          {:ok, value} when is_binary(value) -> value
          _ -> nil
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "_"
  end
end
