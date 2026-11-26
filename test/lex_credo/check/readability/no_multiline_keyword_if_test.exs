defmodule LexCredo.Check.Readability.NoMultilineKeywordIfTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Readability.NoMultilineKeywordIf

  defp run(source, params \\ [], filename \\ "lib/sample.ex") do
    source
    |> Credo.SourceFile.parse(filename)
    |> NoMultilineKeywordIf.run(params)
  end

  test "flags a keyword if spanning multiple lines" do
    source = """
    defmodule Sample do
      def run(x) do
        if valid?(x),
          do: :ok,
          else: :error
      end
    end
    """

    assert [issue] = run(source)
    assert issue.line_no == 3
    assert issue.trigger == "if"
    assert issue.message =~ "do ... end"
  end

  test "flags a keyword if whose value spans multiple lines" do
    source = """
    defmodule Sample do
      def run(x) do
        if x, do: %{
          a: 1
        }
      end
    end
    """

    assert [%{line_no: 3}] = run(source)
  end

  test "flags a multi-line keyword unless" do
    source = """
    defmodule Sample do
      def run(x) do
        unless x,
          do: :ok
      end
    end
    """

    assert [%{trigger: "unless"}] = run(source)
  end

  test "does not flag a one-line keyword if" do
    source = """
    defmodule Sample do
      def run(x) do
        if valid?(x), do: :ok, else: :error
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a block if" do
    source = """
    defmodule Sample do
      def run(x) do
        if valid?(x) do
          :ok
        else
          :error
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag multi-line def by default" do
    source = """
    defmodule Sample do
      def run(x),
        do: x
    end
    """

    assert run(source) == []
  end

  test "supports additional macros" do
    source = """
    defmodule Sample do
      def run(x),
        do: x

      def one(x), do: x
    end
    """

    assert [%{trigger: "def", line_no: 2}] = run(source, macros: [:def])
  end

  test "skips test files when exclude_test_files is true" do
    source = """
    defmodule SampleTest do
      def run(x) do
        if x,
          do: :ok
      end
    end
    """

    assert [_issue] = run(source, [], "test/sample_test.exs")
    assert run(source, [exclude_test_files: true], "test/sample_test.exs") == []
  end

  test "flags the keyword form when do: is not the first key" do
    source = """
    defmodule Sample do
      def run(x) do
        if valid?(x),
          else: :error,
          do: :ok
      end
    end
    """

    assert [%{line_no: 3}] = run(source)
  end

  test "does not flag configured macros without a keyword body" do
    source = """
    defmodule Sample do
      def run(x \\\\ nil)

      def run(x), do: x
    end
    """

    assert run(source, macros: [:def]) == []
  end

  test "returns no issues for source that does not parse" do
    source = """
    defmodule Sample do
      def run(x) do
        if x,
          do: %{a: 1
    end
    """

    assert run(source) == []
  end
end
