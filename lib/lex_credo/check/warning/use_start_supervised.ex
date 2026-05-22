defmodule LexCredo.Check.Warning.UseStartSupervised do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    explanations: [
      check: """
      In test files, use `start_supervised!/1` to start processes instead of
      calling `GenServer.start_link/2`, `Agent.start_link/2`, etc. directly.

      `start_supervised!/1` registers the process with the test supervisor so it
      is automatically cleaned up between tests, even if the test crashes. Direct
      `start_link` calls bypass this and can leave processes running across tests,
      causing hard-to-reproduce failures.

          # BAD
          {:ok, pid} = GenServer.start_link(MyServer, [])
          {:ok, agent} = Agent.start_link(fn -> %{} end)

          # GOOD
          pid = start_supervised!(MyServer)
          agent = start_supervised!({Agent, fn -> %{} end})
      """
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  # Module + function pairs whose direct use is flagged in tests.
  @supervised_starts [
    {[:GenServer], [:start_link, :start]},
    {[:Agent], [:start_link, :start]},
    {[:Task], [:start_link, :start]},
    {[:Supervisor], [:start_link]},
    {[:DynamicSupervisor], [:start_link]}
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.test_file?(source_file) do
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
      |> elem(0)
    else
      []
    end
  end

  defp traverse(
         {{:., meta, [{:__aliases__, _alias_meta, aliases}, fun]}, _call_meta, _args} = ast,
         {issues, issue_meta}
       ) do
    if supervised_start?(aliases, fun) do
      module_name = Enum.join(aliases, ".")

      issue =
        format_issue(issue_meta,
          message:
            "Use `start_supervised!/1` instead of `#{module_name}.#{fun}/2` in tests. " <>
              "`start_supervised!` ensures automatic cleanup between tests.",
          line_no: meta[:line],
          trigger: "#{module_name}.#{fun}"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse(ast, acc), do: {ast, acc}

  defp supervised_start?(aliases, fun) do
    Enum.any?(@supervised_starts, fn {mod_aliases, funs} ->
      aliases == mod_aliases and fun in funs
    end)
  end
end
