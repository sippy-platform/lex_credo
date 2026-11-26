defmodule LexCredo.Check.Readability.PreferPipeOverNestedCallsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Readability.PreferPipeOverNestedCalls

  defp run(source, params \\ [], filename \\ "lib/sample.ex") do
    source
    |> Credo.SourceFile.parse(filename)
    |> PreferPipeOverNestedCalls.run(params)
  end

  defp triggers(body, params \\ []), do: body |> wrap() |> run(params) |> Enum.map(& &1.trigger)

  defp wrap(body) do
    """
    defmodule Sample do
      def run(x, y) do
        #{body}
      end
    end
    """
  end

  test "flags nested local calls" do
    assert [issue] = "f(g(x))" |> wrap() |> run()
    assert issue.trigger == "f"
    assert issue.message =~ "pipeline"
  end

  test "flags nested remote calls" do
    assert ["String.downcase"] == triggers("String.downcase(String.trim(x))")
  end

  test "flags a local call wrapping a remote call and vice versa" do
    assert ["f"] == triggers("f(String.trim(x))")
    assert ["String.trim"] == triggers("String.trim(g(x))")
  end

  test "flags nesting when the outer call has more arguments" do
    assert ["Map.put"] == triggers("Map.put(build(x), :key, y)")
  end

  test "reports a deeply nested chain once" do
    assert ["f"] == triggers("f(g(h(x)))")
  end

  test "flags nested calls inside other arguments of a flagged chain" do
    assert ["f", "a"] == triggers("f(g(x), a(b(y)))")
  end

  test "flags nested calls inside a pipeline step argument" do
    assert ["f"] == triggers("x |> Enum.map(f(g(y)))")
  end

  test "does not flag a call nested in a non-first argument" do
    assert [] == triggers("f(x, g(y))")
  end

  test "does not flag existing pipelines" do
    assert [] == triggers("x |> g() |> f()")
  end

  test "does not flag inner calls without arguments" do
    assert [] == triggers("f(g())")
    assert [] == triggers("Multi.run(Multi.new(), :step, y)")
  end

  test "does not flag field access" do
    assert [] == triggers("Map.get(x.assigns, :user)")
  end

  test "does not treat special forms, macros or operators as pipeable" do
    assert [] == triggers("if valid?(x), do: 1")
    assert [] == triggers("raise ArgumentError, message(x)")
    assert [] == triggers("assert valid?(x)")
    assert [] == triggers("not valid?(x)")
    assert [] == triggers("to_string(x) <> to_string(y)")
    assert [] == triggers("~w(a b)")
  end

  test "does not treat access syntax or interpolation as pipeable" do
    assert [] == triggers("f(x[:key], y)")
    assert [] == triggers("f(x[:a][:b])")
    assert [] == "\"value: \#{inspect(x)}\"" |> triggers()
  end

  test "flags nested calls inside interpolation" do
    assert ["f"] == "\"value: \#{f(g(x))}\"" |> triggers()
  end

  test "does not treat module attribute definitions as calls" do
    source = """
    defmodule Sample do
      @version Mix.Project.config()[:version]
      @label "x\#{inspect(__MODULE__)}"
      @value f(g(1))
    end
    """

    assert ["f"] == source |> run() |> Enum.map(& &1.trigger)
  end

  test "does not flag anonymous function calls" do
    assert [] == triggers("x.(y.(1))")
  end

  test "does not inspect typespecs or guards" do
    source = """
    defmodule Sample do
      @spec run(String.t()) :: Keyword.t(atom())
      def run(x) when is_integer(rem(x, 2)), do: x
    end
    """

    assert run(source) == []
  end

  test "respects min_pipeline_length" do
    assert [] == triggers("f(g(x))", min_pipeline_length: 3)
    assert ["f"] == triggers("f(g(h(x)))", min_pipeline_length: 3)
  end

  test "respects excluded_functions" do
    assert [] == triggers("is_nil(get(x))", excluded_functions: ["is_nil"])
    assert [] == triggers("format(Map.get(x, :a))", excluded_functions: ["Map.get"])
  end

  test "skips test files when exclude_test_files is true" do
    source = wrap("f(g(x))")

    assert [_issue] = run(source, [], "test/sample_test.exs")
    assert run(source, [exclude_test_files: true], "test/sample_test.exs") == []
  end
end
