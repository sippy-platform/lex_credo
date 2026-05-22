defmodule LexCredo.Check.Warning.NoProcessSleepInTests do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Avoid `Process.sleep/1` and `Process.alive?/1` in test files.

      `Process.sleep/1` creates brittle, timing-dependent tests. Use
      `Process.monitor/1` with `assert_receive {:DOWN, ...}` to wait for a
      process to finish, and `Process.alive?/1` can be replaced with the same
      pattern.

      To synchronise before the next call, use `:sys.get_state/1` to ensure the
      process has handled prior messages.

          # BAD
          Process.sleep(100)
          assert Process.alive?(pid)

          # GOOD — wait for process to finish
          ref = Process.monitor(pid)
          assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

          # GOOD — ensure prior messages have been processed
          _ = :sys.get_state(server)
      """,
      params: [
        exclude_test_files:
          "When `true`, skips test files (effectively disabling this check). Default: `false`."
      ]
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.test_file?(source_file) and
         not CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
      |> elem(0)
    else
      []
    end
  end

  defp traverse(
         {{:., meta, [{:__aliases__, _alias_meta, [:Process]}, fun]}, _call_meta, _args} = ast,
         {issues, issue_meta}
       )
       when fun in [:sleep, :alive?] do
    issue =
      format_issue(issue_meta,
        message: message_for(fun),
        line_no: meta[:line],
        trigger: "Process.#{fun}"
      )

    {ast, {[issue | issues], issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  defp message_for(:sleep),
    do:
      "Avoid `Process.sleep/1` in tests. " <>
        "Use `Process.monitor/1` + `assert_receive {:DOWN, ...}` or `:sys.get_state/1` instead."

  defp message_for(:alive?),
    do:
      "Avoid `Process.alive?/1` in tests. " <>
        "Use `Process.monitor/1` + `assert_receive {:DOWN, ...}` instead."
end
