defmodule LexCredo.Check.Warning.UsePositiveTypeGuardsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.UsePositiveTypeGuards

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> UsePositiveTypeGuards.run([])
  end

  test "flags `when not is_nil(x)` in a def" do
    source = """
    defmodule M do
      def call(%{req: req}) when not is_nil(req), do: req
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "positive type guard"
    assert issue.trigger == "not is_nil"
  end

  test "flags `when x != nil` in a def" do
    source = """
    defmodule M do
      def call(%{req: req}) when req != nil, do: req
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "positive type guard"
  end

  test "flags `when nil != x` in a def" do
    source = """
    defmodule M do
      def call(%{req: req}) when nil != req, do: req
    end
    """

    assert [_issue] = run(source)
  end

  test "flags `when x !== nil` in a def" do
    source = """
    defmodule M do
      def call(x) when x !== nil, do: x
    end
    """

    assert [_issue] = run(source)
  end

  test "flags `when not is_nil(x)` in a defp" do
    source = """
    defmodule M do
      defp process(x) when not is_nil(x), do: x
    end
    """

    assert [_issue] = run(source)
  end

  test "flags each violation in a compound `and` guard" do
    source = """
    defmodule M do
      def f(a, b) when not is_nil(a) and not is_nil(b), do: {a, b}
    end
    """

    assert [_issue1, _issue2] = run(source)
  end

  test "flags a negative nil check combined with a valid guard via `and`" do
    source = """
    defmodule M do
      def f(x) when is_integer(x) and x != nil, do: x
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "positive type guard"
  end

  test "does not flag a positive type guard" do
    source = """
    defmodule M do
      def call(%{req: req}) when is_binary(req), do: req
    end
    """

    assert run(source) == []
  end

  test "does not flag a `when` guard with no nil check" do
    source = """
    defmodule M do
      def call(x) when is_integer(x) and x > 0, do: x
    end
    """

    assert run(source) == []
  end

  test "does not flag nil checks in case guards (only function heads)" do
    source = """
    defmodule M do
      def f(x) do
        case x do
          v when not is_nil(v) -> v
          _ -> nil
        end
      end
    end
    """

    assert run(source) == []
  end
end
