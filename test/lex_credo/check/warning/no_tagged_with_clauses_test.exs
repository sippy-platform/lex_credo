defmodule LexCredo.Check.Warning.NoTaggedWithClausesTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoTaggedWithClauses

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> NoTaggedWithClauses.run([])
  end

  test "flags a tagged {:ok, _} with clause" do
    source = """
    defmodule M do
      def f(data) do
        with {:service, {:ok, resp}} <- {:service, call(data)} do
          resp
        end
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "tagged-tuple workarounds"
    assert issue.trigger == "<-"
  end

  test "flags a tagged {:error, _} with clause" do
    source = """
    defmodule M do
      def f(data) do
        with {:step, {:error, reason}} <- {:step, call(data)} do
          {:error, reason}
        end
      end
    end
    """

    assert [_issue] = run(source)
  end

  test "flags multiple tagged clauses in one with expression" do
    source = """
    defmodule M do
      def f(data) do
        with {:service, {:ok, resp}} <- {:service, call(data)},
             {:decode, {:ok, decoded}} <- {:decode, Jason.decode(resp)} do
          decoded
        end
      end
    end
    """

    assert [_issue1, _issue2] = run(source)
  end

  test "does not flag a normal with clause" do
    source = """
    defmodule M do
      def f(data) do
        with {:ok, resp} <- call(data),
             {:ok, decoded} <- decode(resp) do
          decoded
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag when the tag atom differs between left and right" do
    source = """
    defmodule M do
      def f(data) do
        with {:service, {:ok, resp}} <- {:other, call(data)} do
          resp
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a with clause that has no result tuple on the left" do
    source = """
    defmodule M do
      def f(data) do
        with %{value: v} <- fetch(data) do
          v
        end
      end
    end
    """

    assert run(source) == []
  end
end
