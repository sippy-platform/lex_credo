defmodule LexCredo.Check.Readability.NoCommentsInMultilineExpressionsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Readability.NoCommentsInMultilineExpressions

  defp run(source, params \\ [], filename \\ "lib/sample.ex") do
    source
    |> Credo.SourceFile.parse(filename)
    |> NoCommentsInMultilineExpressions.run(params)
  end

  test "flags comments between pipe steps" do
    source = """
    defmodule Sample do
      def build(params) do
        params
        # normalise first
        |> normalize()
        # then save
        |> save()
      end
    end
    """

    assert [first, second] = run(source)
    assert first.line_no == 4
    assert first.trigger == "# normalise first"
    assert first.message =~ "multi-line pipeline"
    assert second.line_no == 6
  end

  test "flags trailing comments on pipe lines" do
    source = """
    defmodule Sample do
      def build(params) do
        params
        |> normalize() # normalise
        |> save()
      end
    end
    """

    assert [%{line_no: 4}] = run(source)
  end

  test "flags comments between map keys" do
    source = """
    defmodule Sample do
      def user do
        %{
          # display name
          name: "a",
          age: 1
        }
      end
    end
    """

    assert [issue] = run(source)
    assert issue.line_no == 4
    assert issue.message =~ "multi-line map"
  end

  test "flags comments inside structs" do
    source = """
    defmodule Sample do
      def user do
        %User{
          name: "a",
          # the age
          age: 1
        }
      end
    end
    """

    assert [%{line_no: 5}] = run(source)
  end

  test "flags comments inside keyword lists" do
    source = """
    defmodule Sample do
      def opts do
        [
          timeout: 5_000,
          # retry a few times
          retries: 3
        ]
      end
    end
    """

    assert [issue] = run(source)
    assert issue.line_no == 5
    assert issue.message =~ "keyword list"
  end

  test "does not flag comments inside plain lists" do
    source = """
    defmodule Sample do
      def deps do
        [
          # runtime
          {:jason, "~> 1.4"},
          {:credo, "~> 1.7"}
        ]
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag comments above an expression" do
    source = """
    defmodule Sample do
      def build(params) do
        # normalise and save
        params
        |> normalize()
        |> save()
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag comments after the closing bracket" do
    source = """
    defmodule Sample do
      def user do
        %{
          name: "a"
        } # trailing
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag comments inside anonymous functions in a pipeline" do
    source = """
    defmodule Sample do
      def build(list) do
        list
        |> Enum.map(fn item ->
          # explain the transformation
          item * 2
        end)
        |> Enum.sum()
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag comments inside do blocks in a map value" do
    source = """
    defmodule Sample do
      def build(x) do
        %{
          value:
            if x do
              # explain
              1
            else
              2
            end
        }
      end
    end
    """

    assert run(source) == []
  end

  test "flags a pipeline nested inside an anonymous function" do
    source = """
    defmodule Sample do
      def build(list) do
        Enum.map(list, fn item ->
          item
          # in between
          |> to_string()
          |> String.trim()
        end)
      end
    end
    """

    assert [%{line_no: 5}] = run(source)
  end

  test "ignores credo directives" do
    source = """
    defmodule Sample do
      def build(params) do
        params
        # credo:disable-for-next-line
        |> normalize()
        |> save()
      end
    end
    """

    assert run(source) == []
  end

  test "respects the kinds parameter" do
    source = """
    defmodule Sample do
      def build(params) do
        params
        # pipe comment
        |> normalize()
        |> Map.merge(%{
          # map comment
          a: 1
        })
      end
    end
    """

    assert [%{line_no: 7}] = run(source, kinds: [:map])
    assert [%{line_no: 4}] = run(source, kinds: [:pipe])
  end

  test "skips test files when exclude_test_files is true" do
    source = """
    defmodule SampleTest do
      def opts do
        [
          # comment
          a: 1
        ]
      end
    end
    """

    assert [_issue] = run(source, [], "test/sample_test.exs")
    assert run(source, [exclude_test_files: true], "test/sample_test.exs") == []
  end

  test "does not flag comments outside any expression" do
    source = """
    # A file header comment
    defmodule Sample do
      def run, do: :ok
    end
    """

    assert run(source) == []
  end

  test "does not flag trailing comments on single-line pipes, maps and keyword lists" do
    source = """
    defmodule Sample do
      def run(params) do
        params |> normalize() |> save() # pipe
        map = %{a: 1} # map
        opts = [a: 1] # keyword
        {map, opts}
      end
    end
    """

    assert run(source) == []
  end

  test "returns no issues for source that does not parse" do
    source = """
    defmodule Sample do
      def run(params) do
        # unclosed
        %{a: 1
    end
    """

    assert run(source) == []
  end
end
