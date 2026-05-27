defmodule LexCredo.Check.Warning.NonBooleanWithStrictOperatorTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NonBooleanWithStrictOperator

  defp run(source, params \\ []) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NonBooleanWithStrictOperator.run(params)
  end

  # ---------------------------------------------------------------------------
  # Flags `and` — non-boolean atom or literal on either side
  # ---------------------------------------------------------------------------

  test "flags and when right operand is a non-boolean atom (:ok)" do
    source = """
    defmodule M do
      def f(data) do
        process(data) and :ok
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "and"
    assert issue.message =~ "&&"
  end

  test "flags and when left operand is nil" do
    source = """
    defmodule M do
      def f(condition) do
        nil and condition
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "and"
  end

  test "flags and when right operand is an integer literal" do
    # Exercises the integer-literal branch of clearly_non_boolean?/1.
    source = """
    defmodule M do
      def f(x) do
        is_integer(x) and 42
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "and"
  end

  # ---------------------------------------------------------------------------
  # Flags `or` — non-boolean atom or literal on either side
  # ---------------------------------------------------------------------------

  test "flags or when right operand is a string literal (fallback pattern)" do
    # A common mistake: `value or "default"` should use `||`.
    source = """
    defmodule M do
      def f(env_var) do
        env_var or "default"
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "or"
    assert issue.message =~ "||"
  end

  test "flags or when right operand is a non-boolean atom (:error)" do
    source = """
    defmodule M do
      def f(result) do
        result or :error
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "or"
  end

  # ---------------------------------------------------------------------------
  # Flags `not` — non-boolean atom or literal as operand
  # ---------------------------------------------------------------------------

  test "flags not when operand is nil" do
    source = """
    defmodule M do
      def f do
        not nil
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "not"
    assert issue.message =~ "!"
  end

  test "flags not when operand is a non-boolean atom" do
    source = """
    defmodule M do
      def f do
        not :ok
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "not"
  end

  # ---------------------------------------------------------------------------
  # Does NOT flag — field access (type cannot be determined statically)
  # ---------------------------------------------------------------------------

  test "does not flag and when operand is a boolean field without ? suffix" do
    # user.active is a common Ecto boolean field — should not be flagged.
    source = """
    defmodule M do
      def f(user) do
        user.active and is_admin?(user)
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag and when left is a chained field access (real-world example)" do
    # data.settings.announce_member_count is a boolean toggle field.
    source = """
    defmodule M do
      def f(data, member_count) do
        if data.settings.announce_member_count and member_count >= data.settings.announce_member_count_minimum do
          :ok
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag and when right operand is a field access (Enum.find_value pattern)" do
    # &1.id is a field access — type unknown statically.
    source = """
    defmodule M do
      def f(accounts, number) do
        Enum.find_value(accounts, &(&1.extension.exten == number and &1.id))
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Does NOT flag — boolean expressions, variables, unknown calls
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

  test "does not flag and when operand is an unknown function call" do
    source = """
    defmodule M do
      def f(condition) do
        MyMod.fetch() and condition
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Test-file exclusion
  # ---------------------------------------------------------------------------

  test "does not flag when exclude_test_files: true and file is a test file" do
    source = """
    defmodule M do
      def f(result) do
        result or :error
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
