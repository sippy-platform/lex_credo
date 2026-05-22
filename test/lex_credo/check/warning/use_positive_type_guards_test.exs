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

  test "flags `when not is_binary(x)` in a def" do
    source = """
    defmodule M do
      def validate(x) when not is_binary(x), do: {:error, :not_a_string}
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "positive type guard"
    assert issue.trigger == "not is_binary"
  end

  test "flags `when not is_integer(x)` in a def" do
    source = """
    defmodule M do
      def validate(x) when not is_integer(x), do: {:error, :not_an_integer}
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "not is_integer"
  end

  test "flags `when not is_atom(x)` in a def" do
    source = """
    defmodule M do
      def f(x) when not is_atom(x), do: x
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "not is_atom"
  end

  test "flags `when x != nil` in a def" do
    source = """
    defmodule M do
      def call(%{req: req}) when req != nil, do: req
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "positive type guard"
    assert issue.trigger == "!= nil"
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

    assert [issue] = run(source)
    assert issue.trigger == "!== nil"
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
      def f(a, b) when not is_nil(a) and not is_binary(b), do: {a, b}
    end
    """

    assert [issue1, issue2] = run(source)
    assert issue1.trigger == "not is_nil"
    assert issue2.trigger == "not is_binary"
  end

  test "flags a mixed negated type guard combined with a valid guard via `and`" do
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

  test "does not flag a `when` guard with no negation" do
    source = """
    defmodule M do
      def call(x) when is_integer(x) and x > 0, do: x
    end
    """

    assert run(source) == []
  end

  test "does not flag negated type guards in case guards (only function heads)" do
    source = """
    defmodule M do
      def f(x) do
        case x do
          v when not is_nil(v) -> v
          _other -> nil
        end
      end
    end
    """

    assert run(source) == []
  end
end
