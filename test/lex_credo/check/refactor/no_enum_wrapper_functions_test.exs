defmodule LexCredo.Check.Refactor.NoEnumWrapperFunctionsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Refactor.NoEnumWrapperFunctions

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NoEnumWrapperFunctions.run([])
  end

  test "flags a def whose body is only Enum.map" do
    source = """
    defmodule M do
      def parse_items(list), do: Enum.map(list, &String.to_integer/1)
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Avoid wrapping"
    assert issue.trigger == "def"
  end

  test "does not flag a defp whose body is only Enum.filter (aggregation, not transformation)" do
    source = """
    defmodule M do
      defp active_users(users), do: Enum.filter(users, & &1.active)
    end
    """

    assert run(source) == []
  end

  test "flags a def with a block body that is only Enum.each" do
    source = """
    defmodule M do
      def notify_all(users) do
        Enum.each(users, &send_email/1)
      end
    end
    """

    assert [_issue] = run(source)
  end

  test "flags a def wrapping Stream.map" do
    source = """
    defmodule M do
      def stream_parse(list), do: Stream.map(list, &String.to_integer/1)
    end
    """

    assert [_issue] = run(source)
  end

  test "does not flag a def with multiple expressions in the body" do
    source = """
    defmodule M do
      def process(list) do
        validated = validate(list)
        Enum.map(validated, &transform/1)
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a def that calls Enum.map but also does other work" do
    source = """
    defmodule M do
      def parse_and_log(list) do
        result = Enum.map(list, &String.to_integer/1)
        Logger.info("Parsed \#{length(result)} items")
        result
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a def that calls a local function (not Enum/Stream)" do
    source = """
    defmodule M do
      def process(list), do: do_process(list)
      defp do_process(list), do: list
    end
    """

    assert run(source) == []
  end

  test "does not flag a def that only calls a non-collection Enum function" do
    source = """
    defmodule M do
      def to_list(map), do: Map.keys(map)
    end
    """

    assert run(source) == []
  end

  test "flags a def wrapping Enum.flat_map" do
    source = """
    defmodule M do
      def expand(lists), do: Enum.flat_map(lists, & &1)
    end
    """

    assert [_issue] = run(source)
  end

  test "flags a defp wrapping Enum.map" do
    source = """
    defmodule M do
      defp names(users), do: Enum.map(users, & &1.name)
    end
    """

    assert [_issue] = run(source)
  end

  test "does not flag a test file when exclude_test_files: true" do
    source = """
    defmodule M do
      def names(users), do: Enum.map(users, & &1.name)
    end
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/support/helpers.ex")
      |> NoEnumWrapperFunctions.run(exclude_test_files: true)

    assert issues == []
  end
end
