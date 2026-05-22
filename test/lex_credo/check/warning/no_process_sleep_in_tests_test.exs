defmodule LexCredo.Check.Warning.NoProcessSleepInTestsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoProcessSleepInTests

  defp run(source, filename \\ "test/my_test.exs") do
    source
    |> Credo.SourceFile.parse(filename)
    |> NoProcessSleepInTests.run([])
  end

  test "flags Process.sleep/1 in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "waits" do
        spawn(fn -> :ok end)
        Process.sleep(100)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Process.sleep"
    assert issue.trigger == "Process.sleep"
  end

  test "flags Process.alive?/1 in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "checks alive" do
        pid = spawn(fn -> :ok end)
        assert Process.alive?(pid)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "Process.alive?"
    assert issue.trigger == "Process.alive?"
  end

  test "flags both Process.sleep and Process.alive? in the same file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "bad practices" do
        pid = spawn(fn -> :ok end)
        Process.sleep(50)
        assert Process.alive?(pid)
      end
    end
    """

    assert [_issue1, _issue2] = run(source)
  end

  test "does not flag Process.sleep in a non-test file" do
    source = """
    defmodule MyModule do
      def wait, do: Process.sleep(1000)
    end
    """

    assert run(source, "lib/my_module.ex") == []
  end

  test "does not flag Process.alive? in a non-test file" do
    source = """
    defmodule MyModule do
      def alive?(pid), do: Process.alive?(pid)
    end
    """

    assert run(source, "lib/my_module.ex") == []
  end

  test "flags Process.sleep in a file under test/ that is not a _test.exs" do
    source = """
    defmodule TestSupport do
      def slow_setup do
        Process.sleep(200)
      end
    end
    """

    assert [issue] = run(source, "test/support/helpers.ex")
    assert issue.message =~ "Process.sleep"
  end
end
