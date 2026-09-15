defmodule LexCredo.Check.Warning.NamedOtpBuiltinsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NamedOtpBuiltins

  defp run(source) do
    source
    |> Credo.SourceFile.parse("lib/my_app/application.ex")
    |> NamedOtpBuiltins.run([])
  end

  test "flags a DynamicSupervisor child spec without a name" do
    source = """
    children = [
      {DynamicSupervisor, strategy: :one_for_one}
    ]
    """

    assert [issue] = run(source)
    assert issue.trigger == "DynamicSupervisor"
    assert issue.message =~ "`name:`"
  end

  test "flags a Registry child spec without a name" do
    source = """
    children = [
      {Registry, keys: :unique}
    ]
    """

    assert [issue] = run(source)
    assert issue.trigger == "Registry"
  end

  test "does not flag named child specs" do
    source = """
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: MyApp.DynamicSupervisor},
      {Registry, keys: :unique, name: MyApp.Registry}
    ]
    """

    assert run(source) == []
  end

  test "does not flag other child specs" do
    source = """
    children = [
      {Task.Supervisor, name: MyApp.TaskSupervisor},
      {MyApp.Worker, []}
    ]
    """

    assert run(source) == []
  end

  test "does not flag dynamically assembled options" do
    source = """
    options = [strategy: :one_for_one]
    children = [{DynamicSupervisor, options}]
    """

    assert run(source) == []
  end

  test "does not flag a test file when exclude_test_files: true" do
    source = """
    children = [{DynamicSupervisor, strategy: :one_for_one}]
    """

    issues =
      source
      |> Credo.SourceFile.parse("test/my_test.exs")
      |> NamedOtpBuiltins.run(exclude_test_files: true)

    assert issues == []
  end
end
