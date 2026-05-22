defmodule LexCredo.Check.Warning.NoEnumAllAssert do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    explanations: [
      check: """
      Avoid `assert Enum.all?/2` in test files. Use `for` with individual
      assertions instead.

      `assert Enum.all?(collection, predicate)` only tells you that at least one
      element failed. A `for` loop with individual `assert` calls pinpoints the
      exact failing element, making failures much easier to diagnose.

          # BAD — only tells you something failed, not which element
          assert Enum.all?(posts, &match?(%Post{}, &1))

          # GOOD — reports exactly which element failed
          for post <- posts, do: assert %Post{} = post
      """
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

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

  # assert Enum.all?(collection, fun)
  defp traverse(
         {:assert, _assert_meta,
          [
            {{:., dot_meta, [{:__aliases__, _, [:Enum]}, :all?]}, _call_meta, _args}
          ]} = ast,
         {issues, issue_meta}
       ) do
    issue =
      format_issue(issue_meta,
        message:
          "Use `for` with individual assertions instead of `assert Enum.all?/2`. " <>
            "`for` reports exactly which element failed.",
        line_no: dot_meta[:line],
        trigger: "Enum.all?"
      )

    {ast, {[issue | issues], issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}
end
