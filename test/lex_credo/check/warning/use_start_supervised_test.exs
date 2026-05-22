defmodule LexCredo.Check.Warning.UseStartSupervisedTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.UseStartSupervised

  defp run(source, filename \\ "test/my_test.exs") do
    source
    |> Credo.SourceFile.parse(filename)
    |> UseStartSupervised.run([])
  end

  test "flags GenServer.start_link in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts server" do
        {:ok, pid} = GenServer.start_link(MyServer, [])
        assert is_pid(pid)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "start_supervised!"
    assert issue.trigger == "GenServer.start_link"
  end

  test "flags Agent.start_link in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts agent" do
        {:ok, agent} = Agent.start_link(fn -> %{} end)
        assert is_pid(agent)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "Agent.start_link"
  end

  test "flags Agent.start in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts agent" do
        {:ok, agent} = Agent.start(fn -> %{} end)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "Agent.start"
  end

  test "flags Supervisor.start_link in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts supervisor" do
        {:ok, sup} = Supervisor.start_link([], strategy: :one_for_one)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "Supervisor.start_link"
  end

  test "flags GenServer.start (without link) in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts server without link" do
        {:ok, pid} = GenServer.start(MyServer, [])
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "GenServer.start"
  end

  test "flags Task.start_link in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts task" do
        {:ok, _pid} = Task.start_link(fn -> :ok end)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "Task.start_link"
  end

  test "flags DynamicSupervisor.start_link in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "starts dynamic supervisor" do
        {:ok, _sup} = DynamicSupervisor.start_link(strategy: :one_for_one)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "DynamicSupervisor.start_link"
  end

  test "does not flag GenServer.start_link in a non-test file" do
    source = """
    defmodule MyApp.Application do
      use Application

      def start(_type, _args) do
        children = [{MyServer, []}]
        {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
      end
    end
    """

    assert run(source, "lib/my_app/application.ex") == []
  end

  test "does not flag other GenServer functions" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "calls server" do
        pid = start_supervised!(MyServer)
        GenServer.call(pid, :ping)
        GenServer.cast(pid, :reset)
      end
    end
    """

    assert run(source) == []
  end
end
