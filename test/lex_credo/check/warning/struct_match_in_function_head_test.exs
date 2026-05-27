defmodule LexCredo.Check.Warning.StructMatchInFunctionHeadTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.StructMatchInFunctionHead

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/example.ex")
    |> StructMatchInFunctionHead.run([])
  end

  # ---------------------------------------------------------------------------
  # Flagged — basic cases
  # ---------------------------------------------------------------------------

  test "flags %Struct{} = param at the top of a def body" do
    source = """
    defmodule M do
      def process(data) do
        %User{name: name} = data
        name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "%User{}"
    assert issue.message =~ "data"
    assert issue.trigger == "="
  end

  test "flags %Struct{} = param at the top of a defp body" do
    source = """
    defmodule M do
      defp process(data) do
        %User{name: name} = data
        name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "%User{}"
  end

  test "flags when the struct match is not the first statement" do
    source = """
    defmodule M do
      def process(data) do
        Logger.debug("processing")
        %User{name: name} = data
        name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "data"
  end

  test "flags a struct match in an inline def body" do
    source = """
    defmodule M do
      def process(data), do: %User{name: name} = data
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "%User{}"
  end

  test "flags when the function has a guard" do
    source = """
    defmodule M do
      def process(data) when is_map(data) do
        %User{name: name} = data
        name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "data"
  end

  test "flags when the function has a default-value parameter" do
    source = """
    defmodule M do
      def process(data \\\\ %User{}) do
        %User{name: name} = data
        name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "data"
  end

  test "flags a namespaced struct" do
    source = """
    defmodule M do
      def process(data) do
        %MyApp.User{name: name} = data
        name
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "%MyApp.User{}"
  end

  test "flags a %__MODULE__{} match against a param" do
    source = """
    defmodule M do
      def process(data) do
        %__MODULE__{field: val} = data
        val
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "%__MODULE__{}"
  end

  test "flags multiple params each matched as a struct" do
    source = """
    defmodule M do
      def f(a, b) do
        %User{} = a
        %Post{} = b
        {a, b}
      end
    end
    """

    assert [_issue1, _issue2] = run(source)
  end

  test "flags a %_{} wildcard struct match against a param" do
    source = """
    defmodule M do
      def process(data) do
        %_{id: id} = data
        id
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "%_{}"
  end

  # ---------------------------------------------------------------------------
  # Not flagged — already in the head
  # ---------------------------------------------------------------------------

  test "does not flag when the struct is already matched in the head" do
    source = """
    defmodule M do
      def process(%User{name: name}) do
        name
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag when the struct is matched with a binding in the head" do
    source = """
    defmodule M do
      def process(%User{name: name} = data) do
        {name, data}
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Not flagged — not a parameter variable
  # ---------------------------------------------------------------------------

  test "does not flag a struct match on a local variable" do
    source = """
    defmodule M do
      def process(input) do
        data = fetch(input)
        %User{name: name} = data
        name
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a struct match on a sub-pattern variable" do
    # data comes from a tuple destructuring in the head — not a plain param
    source = """
    defmodule M do
      def process({:ok, data}) do
        %User{name: name} = data
        name
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Not flagged — plain map (not a named struct)
  # ---------------------------------------------------------------------------

  test "does not flag a plain map match" do
    source = """
    defmodule M do
      def process(data) do
        %{name: name} = data
        name
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Not flagged — struct match nested inside control flow
  # ---------------------------------------------------------------------------

  test "does not flag a struct match inside a case branch" do
    source = """
    defmodule M do
      def process(data) do
        case condition() do
          true ->
            %User{name: name} = data
            name
          false ->
            nil
        end
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a struct match inside an anonymous function" do
    source = """
    defmodule M do
      def process(data) do
        fn arg ->
          %User{name: name} = arg
          name
        end
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # Not flagged — _ and _-prefixed anonymous params
  # ---------------------------------------------------------------------------

  test "does not flag when param is the bare _ wildcard" do
    source = """
    defmodule M do
      def process(_) do
        %User{} = build_user()
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag a zero-arity function" do
    # Exercises plain_param_names(_) catch-all: `def f do` has nil args (no list).
    source = """
    defmodule M do
      def build do
        %User{} = fetch_user()
      end
    end
    """

    assert run(source) == []
  end

  # ---------------------------------------------------------------------------
  # exclude_test_files
  # ---------------------------------------------------------------------------

  test "does not flag a test file when exclude_test_files: true" do
    source = """
    defmodule M do
      def process(data) do
        %User{name: name} = data
        name
      end
    end
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/my_test.exs")
      |> StructMatchInFunctionHead.run(exclude_test_files: true)

    assert issues == []
  end
end
