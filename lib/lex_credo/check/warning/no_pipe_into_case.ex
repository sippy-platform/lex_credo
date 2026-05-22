defmodule LexCredo.Check.Warning.NoPipeIntoCase do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Do not pipe into `case` expressions.

      Assign intermediate results to a variable and pass it to `case` directly.
      Piping into `case` is hard to read and can obscure the subject of the match.

          # BAD
          build_post(attrs)
          |> store_post()
          |> case do
            {:ok, post} -> post
            {:error, _} -> nil
          end

          # GOOD
          changeset = build_post(attrs)
          case store_post(changeset) do
            {:ok, post} -> post
            {:error, _} -> nil
          end
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`."
      ]
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
      |> elem(0)
    end
  end

  defp traverse(
         {:|>, meta, [_left, {:case, _case_meta, _case_clauses}]} = ast,
         {issues, issue_meta}
       ) do
    issue =
      format_issue(issue_meta,
        message:
          "Do not pipe into `case`. Assign the result to a variable and pass it to `case` directly.",
        line_no: meta[:line],
        trigger: "|>"
      )

    {ast, {[issue | issues], issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}
end
