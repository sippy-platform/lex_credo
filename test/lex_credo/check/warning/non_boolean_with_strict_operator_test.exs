defmodule LexCredo.Check.Warning.NonBooleanWithStrictOperatorTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NonBooleanWithStrictOperator

  defp run(source, params \\ []) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NonBooleanWithStrictOperator.run(params)
  end

  # ---------------------------------------------------------------------------
  # Flags `and`
  # ---------------------------------------------------------------------------

  test "flags and when right operand is a non-? field access" do
    source = """
    defmodule M do
      def f(accounts, number) do
        Enum.find_value(accounts, &(&1.extension.exten == number and &1.id))
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "and"
    assert issue.message =~ "&&"
  end

  test "flags and when left operand is a non-? field access" do
    source = """
    defmodule M do
      def f(user) do
        user.name and is_valid?(user)
      end
    end
    """

    assert [_issue] = run(source)
  end

  test "flags and when right operand is a non-boolean integer literal" do
    source = """
    defmodule M do
      def f(x) do
        is_integer(x) and 42
      end
    end
    """

    assert [_issue] = run(source)
  end

  test "flags and when right operand is the nil atom" do
    source = """
    defmodule M do
      def f(condition) do
        condition and nil
      end
    end
    """

    assert [_issue] = run(source)
  end

  # ---------------------------------------------------------------------------
  # Flags `or`
  # ---------------------------------------------------------------------------

  test "flags or when an operand is a non-? field access" do
    source = """
    defmodule M do
      def f(a) do
        is_nil(a) or a.value
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "or"
    assert issue.message =~ "||"
  end

  # ---------------------------------------------------------------------------
  # Flags `not`
  # ---------------------------------------------------------------------------

  test "flags not when operand is a non-? field access" do
    source = """
    defmodule M do
      def f(x) do
        not x.name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "not"
    assert issue.message =~ "!"
  end

  # ---------------------------------------------------------------------------
  # Does NOT flag
  # ---------------------------------------------------------------------------

  test "does not flag and when both operands are boolean guard calls" do
    source = """
    defmodule M do
      def f(x, y) do
        is_binary(x) and is_integer(y)
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag and when operand is a ?-suffixed field access" do
    source = """
    defmodule M do
      def f(user) do
        user.active? and is_admin?(user)
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag and with plain variables" do
    source = """
    defmodule M do
      def f(a, b) do
        a and b
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag or with plain variables" do
    source = """
    defmodule M do
      def f(a, b) do
        a or b
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag not with a boolean guard call" do
    source = """
    defmodule M do
      def f(x) do
        not is_nil(x)
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag and when left operand is a module-qualified call" do
    source = """
    defmodule M do
      def f(condition) do
        MyMod.fetch() and condition
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag when exclude_test_files: true and file is a test file" do
    source = """
    defmodule M do
      def f(accounts, number) do
        Enum.find_value(accounts, &(&1.extension.exten == number and &1.id))
      end
    end
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/my_test.exs")
      |> NonBooleanWithStrictOperator.run(exclude_test_files: true)

    assert issues == []
  end
end
