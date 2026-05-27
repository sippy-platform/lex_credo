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

  test "does not flag || when the inner && operands are not boolean-like" do
    # (user && user.name) || "default" is pure truthy/falsy — should not be flagged
    source = """
    defmodule M do
      def f(user) do
        (user && user.name) || "default"
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag && when both operands are plain variables" do
    source = """
    defmodule M do
      def f(a, b) do
        a && b
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag || when only the left operand is boolean-like" do
    # !x is always boolean, so or is technically safe — but the right operand y
    # is unknown type, meaning the expression can return a non-boolean. Using
    # `or` there would be misleading, so we don't flag it.
    source = """
    defmodule M do
      def f(x, y) do
        !x || y
      end
    end
    """

    assert run(source) == []
  end

  test "flags both the inner && and the outer || when all operands are boolean-like" do
    source = """
    defmodule M do
      def f(x, y, z) do
        (is_binary(x) && is_integer(y)) || is_atom(z)
      end
    end
    """

    issues = run(source)
    triggers = Enum.map(issues, & &1.trigger)
    assert "&&" in triggers
    assert "||" in triggers
  end

  test "flags && when left operand is a boolean-like || subexpression" do
    # Exercises boolean_like?({:||, ...}) — || is an operand of &&, so it
    # must itself be checked for boolean-likeness recursively.
    source = """
    defmodule M do
      def f(a, b, c) do
        (is_nil(a) || is_atom(b)) && is_binary(c)
      end
    end
    """

    issues = run(source)
    triggers = Enum.map(issues, & &1.trigger)
    assert "&&" in triggers
  end

  test "does not flag && when only the right operand is boolean-like (literal true)" do
    # x may be nil — `x and true` would raise, `x && true` returns nil.
    source = """
    defmodule M do
      def f(x) do
        x && true
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag && when only the right operand is boolean-like (literal false)" do
    source = """
    defmodule M do
      def f(x) do
        x && false
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag && when only the right operand is boolean-like (is_* call)" do
    # user may be nil — `user and is_nil(user.name)` would raise.
    source = """
    defmodule M do
      def f(user) do
        user && is_nil(user.name)
      end
    end
    """

    assert run(source) == []
  end

  test "flags && when right operand is the literal true and left is boolean-like" do
    # Exercises boolean_like?(true) on the right; left is also boolean-like.
    source = """
    defmodule M do
      def f(x) do
        is_integer(x) && true
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "&&"
  end

  test "does not flag a test file when exclude_test_files: true" do
    source = """
    defmodule M do
      def f(a, b) do
        if is_binary(a) && is_integer(b), do: {a, b}
      end
    end
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/my_test.exs")
      |> PreferBooleanOperators.run(exclude_test_files: true)

    assert issues == []
  end
end
