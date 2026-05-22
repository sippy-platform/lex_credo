defmodule LexCredo.Check.Warning.NoBareWildcardInCase do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      When matching on `{:ok, ...}` / `{:error, ...}` result tuples in a `case`
      expression, use a named catch-all variable instead of a bare `_`.

      A bare `_` gives no hint of what is being discarded. A named variable like
      `_error` or `_error_tuple` communicates intent and makes the code easier to
      understand and maintain.

          # BAD
          case some_function(arg) do
            {:ok, value} -> value
            _ -> nil
          end

          # GOOD
          case some_function(arg) do
            {:ok, value} -> value
            _error -> nil
          end

          # BETTER: fully explicit when the shape matters
          case some_function(arg) do
            {:ok, value} -> value
            {:error, reason} -> raise "unexpected: \#{inspect(reason)}"
          end
      """
    ]

  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
    |> elem(0)
  end

  defp traverse({:case, _meta, [_expr, [do: clauses]]} = ast, {issues, issue_meta}) do
    new_issues =
      if any_result_tuple_clause?(clauses) do
        clauses
        |> Enum.filter(&bare_wildcard_clause?/1)
        |> Enum.map(fn {:->, meta, _} ->
          format_issue(issue_meta,
            message:
              "Use a named catch-all (e.g. `_error`) instead of bare `_` " <>
                "when matching on result tuples.",
            line_no: meta[:line],
            trigger: "_"
          )
        end)
      else
        []
      end

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  # Returns the pattern from a case clause, unwrapping any `when` guard.
  defp clause_pattern({:->, _meta, [[{:when, _, [pattern | _]}], _]}), do: pattern
  defp clause_pattern({:->, _meta, [[pattern], _]}), do: pattern
  defp clause_pattern(_), do: nil

  # 2-element result tuples: {:ok, _} / {:error, _}
  defp result_tuple_pattern?({:ok, _}), do: true
  defp result_tuple_pattern?({:error, _}), do: true
  # 3+ element result tuples: {:ok, a, b} etc.
  defp result_tuple_pattern?({:{}, _, [:ok | _]}), do: true
  defp result_tuple_pattern?({:{}, _, [:error | _]}), do: true
  defp result_tuple_pattern?(_), do: false

  # Bare `_` wildcard: `{:_, meta, nil}` in the AST.
  defp bare_wildcard_pattern?({:_, _meta, nil}), do: true
  defp bare_wildcard_pattern?(_), do: false

  defp any_result_tuple_clause?(clauses) do
    Enum.any?(clauses, fn clause -> clause |> clause_pattern() |> result_tuple_pattern?() end)
  end

  defp bare_wildcard_clause?(clause) do
    clause |> clause_pattern() |> bare_wildcard_pattern?()
  end
end
