defmodule LexCredo.Check.Warning.PreferBooleanOperatorsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.PreferBooleanOperators

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> PreferBooleanOperators.run([])
  end

  test "flags && when left operand is an is_* call" do
    source = """
    defmodule M do
      def f(a, b) do
        if is_binary(a) && is_integer(b), do: {a, b}
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Use `and`"
    assert issue.trigger == "&&"
  end

  test "flags && when right operand is a comparison" do
    source = """
    defmodule M do
      def f(x) do
        if x > 0 && x < 100, do: x
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "&&"
  end

  test "flags || when an operand is an is_* call" do
    source = """
    defmodule M do
      def f(x) do
        if is_nil(x) || is_atom(x), do: :ok
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Use `or`"
    assert issue.trigger == "||"
  end

  test "flags ! when the operand is an is_* call" do
    source = """
    defmodule M do
      def f(x) do
        if !is_nil(x), do: x
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Use `not`"
    assert issue.trigger == "!"
  end

  test "flags ! when the operand is a comparison" do
    source = """
    defmodule M do
      def f(x) do
        unless !(x == :done), do: :ok
      end
    end
    """

    assert [_issue] = run(source)
  end

  test "does not flag && when neither operand is boolean-like" do
    source = """
    defmodule M do
      def f(a, b) do
        a && b
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag || when neither operand is boolean-like" do
    source = """
    defmodule M do
      def f(a, b) do
        a || b
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag ! on a non-boolean-like operand" do
    source = """
    defmodule M do
      def f(x) do
        !x
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag and/or/not" do
    source = """
    defmodule M do
      def f(a, b) do
        if is_binary(a) and is_integer(b), do: {a, b}
      end
    end
    """

    assert run(source) == []
  end
end
