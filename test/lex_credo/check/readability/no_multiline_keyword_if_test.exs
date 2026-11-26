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
end
