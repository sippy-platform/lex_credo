defmodule LexCredo.Check.Readability.ModuleAttributesBeforeFunctionsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Readability.ModuleAttributesBeforeFunctions

  defp run(source, params \\ [], filename \\ "lib/sample.ex") do
    source
    |> Credo.SourceFile.parse(filename)
    |> ModuleAttributesBeforeFunctions.run(params)
  end

  test "flags a type declared after a function" do
    source = """
    defmodule Sample do
      def run(x), do: x

      @type t :: integer()
    end
    """

    assert [issue] = run(source)
    assert issue.line_no == 4
    assert issue.trigger == "@type"
    assert issue.message =~ "Type `@type`"
  end

  test "flags typep, opaque and callback after a function" do
    source = """
    defmodule Sample do
      defp run(x), do: x

      @typep a :: atom()
      @opaque b :: map()
      @callback c() :: :ok
    end
    """

    assert ~w[@typep @opaque @callback] == source |> run() |> Enum.map(& &1.trigger)
  end

  test "flags a constant declared after a function" do
    source = """
    defmodule Sample do
      def run, do: @timeout

      @timeout 5_000
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "@timeout"
    assert issue.message =~ "Module attribute `@timeout`"
  end

  test "does not flag attributes declared before functions" do
    source = """
    defmodule Sample do
      @moduledoc false
      @behaviour GenServer
      @type t :: integer()
      @timeout 5_000

      def run, do: @timeout
    end
    """

    assert run(source) == []
  end

  test "does not flag function annotations between functions" do
    source = """
    defmodule Sample do
      def a, do: 1

      @doc "B"
      @spec b() :: integer()
      @deprecated "use a/0"
      @dialyzer {:nowarn_function, b: 0}
      @compile {:inline, b: 0}
      def b, do: 2

      @impl true
      def init(state), do: {:ok, state}
    end
    """

    assert run(source) == []
  end

  test "does not flag ExUnit tags" do
    source = """
    defmodule SampleTest do
      use ExUnit.Case

      defp helper, do: :ok

      @tag :slow
      @describetag :db
      test "works", do: helper()
    end
    """

    assert run(source, [], "test/sample_test.exs") == []
  end

  test "does not flag attribute reads at module level" do
    source = """
    defmodule Sample do
      @value 1
      def run, do: @value
      @value
    end
    """

    assert run(source) == []
  end

  test "allows configured attributes" do
    source = """
    defmodule Sample do
      def a, do: 1

      @desc "B"
      def b, do: 2
    end
    """

    assert [_issue] = run(source)
    assert run(source, allowed_attributes: [:desc]) == []
  end

  test "checks nested modules independently" do
    source = """
    defmodule Outer do
      @outer 1

      defmodule Inner do
        @inner 1
        def run, do: @inner
        @late 2
      end

      def run, do: @outer
    end
    """

    assert [%{trigger: "@late"}] = run(source)
  end

  test "treats defmacro and defdelegate as function definitions" do
    source = """
    defmodule Sample do
      defdelegate run(x), to: Other
      @a 1

      defmacro m, do: nil
    end
    """

    assert [%{trigger: "@a"}] = run(source)
  end

  test "skips test files when exclude_test_files is true" do
    source = """
    defmodule SampleTest do
      def a, do: 1
      @late 1
    end
    """

    assert [_issue] = run(source, [], "test/sample_test.exs")
    assert run(source, [exclude_test_files: true], "test/sample_test.exs") == []
  end
end
