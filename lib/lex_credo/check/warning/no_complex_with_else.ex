defmodule LexCredo.Check.Warning.NoComplexWithElse do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    param_defaults: [max_else_clauses: 1, exclude_test_files: false],
    explanations: [
      check: """
      Avoid complex `else` blocks in `with` expressions.

      When multiple clauses can fail and each needs different handling, normalise
      error return types in small private helper functions so the `with` expression
      focuses only on the happy path. If you genuinely need to distinguish error
      sources, use `case` instead.

          # BAD — hard to tell which clause produced which error
          with {:ok, a} <- step_a(),
               {:ok, b} <- step_b() do
            ...
          else
            {:error, :not_found} -> ...
            {:error, :forbidden} -> ...
          end

          # GOOD — each helper normalises its own error
          defp step_a, do: ...
          defp step_b, do: ...
      """,
      params: [
        max_else_clauses: "Maximum number of `else` clauses allowed (default: 1).",
        exclude_test_files: "When `true`, skips test files. Default: `false`."
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      max = Params.get(params, :max_else_clauses, __MODULE__)

      Credo.Code.prewalk(source_file, &traverse(&1, &2, max), {[], issue_meta})
      |> elem(0)
    end
  end

  defp traverse({:with, meta, args} = ast, {issues, issue_meta}, max) do
    else_clauses = get_else_clauses(args)

    if length(else_clauses) > max do
      issue =
        format_issue(issue_meta,
          message:
            "Avoid complex `else` blocks in `with` expressions (#{length(else_clauses)} clauses). " <>
              "Normalise errors in helper functions or use `case` when the error source matters.",
          line_no: meta[:line],
          trigger: "with"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse(ast, acc, _max), do: {ast, acc}

  defp get_else_clauses(args) do
    opts = Enum.find(args, fn arg -> is_list(arg) and Keyword.has_key?(arg, :else) end)

    case opts do
      nil -> []
      keyword_list -> Keyword.get(keyword_list, :else, [])
    end
  end
end
