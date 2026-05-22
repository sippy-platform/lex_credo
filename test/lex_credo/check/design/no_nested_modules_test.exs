defmodule LexCredo.Check.Design.NoNestedModulesTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Design.NoNestedModules

  defp run(source, filename \\ "lib/example.ex") do
    source
    |> Credo.SourceFile.parse(filename)
    |> NoNestedModules.run([])
  end

  test "flags a module nested inside another module" do
    source = """
    defmodule Outer do
      defmodule Inner do
        def hello, do: :world
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Do not nest module definitions"
    assert issue.line_no == 2
  end

  test "flags multiple nested modules" do
    source = """
    defmodule Outer do
      defmodule InnerA do
      end

      defmodule InnerB do
      end
    end
    """

    issues = run(source)
    assert length(issues) == 2
  end

  test "flags doubly nested modules separately" do
    source = """
    defmodule A do
      defmodule B do
        defmodule C do
        end
      end
    end
    """

    issues = run(source)
    assert length(issues) == 2
  end

  test "does not flag a single top-level module" do
    source = """
    defmodule MyModule do
      def hello, do: :world
    end
    """

    assert run(source) == []
  end

  test "does not flag two top-level modules in one file" do
    source = """
    defmodule ModuleA do
    end

    defmodule ModuleB do
    end
    """

    assert run(source) == []
  end

  test "does not flag nested modules in test files" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      defmodule HelperSchema do
        use Ecto.Schema
      end
    end
    """

    assert run(source, "test/my_test.exs") == []
  end

  test "does not flag nested modules in files under /test/ directory" do
    source = """
    defmodule MyTest do
      defmodule Fixture do
      end
    end
    """

    assert run(source, "test/support/my_test.ex") == []
  end

  test "flags nested modules in test files when exclude_test_files: false" do
    source = """
    defmodule MyTest do
      defmodule Helper do
      end
    end
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/support/helpers.ex")
      |> NoNestedModules.run(exclude_test_files: false)

    assert [issue] = issues
    assert issue.message =~ "Do not nest module definitions"
  end
end
