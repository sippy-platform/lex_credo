defmodule LexCredo.Check.Warning.UsePositiveTypeGuards do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      Use positive type guards instead of negated nil checks in function guards.

      `is_binary(req)` is more precise than `not is_nil(req)` — it will catch
      unexpected types (integers, lists, etc.) that `not is_nil` silently passes.

          # BAD: passes any non-nil value, including integers, lists, etc.
          def call_service(%{req: req}) when not is_nil(req), do: ...
          def call_service(%{req: req}) when req != nil, do: ...

          # GOOD: precise about what is actually expected
          def call_service(%{req: req}) when is_binary(req), do: ...
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

  # Match `def`/`defp` with a `when` guard in the function head.
  defp traverse(
         {def_type, _def_meta, [{:when, when_meta, [_head, guard]} | _body]} = ast,
         {issues, issue_meta}
       )
       when def_type in [:def, :defp] do
    new_issues =
      guard
      |> collect_negative_nil_positions()
      |> Enum.map(fn line ->
        format_issue(issue_meta,
          message:
            "Use a positive type guard (e.g. `is_binary(x)`) instead of a " <>
              "negated nil check (`not is_nil(x)` or `x != nil`).",
          line_no: line || when_meta[:line],
          trigger: "not is_nil"
        )
      end)

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  # `not is_nil(x)` — most common form
  defp collect_negative_nil_positions({:not, meta, [{:is_nil, _is_nil_meta, _is_nil_args}]}),
    do: [meta[:line]]

  # `x != nil` or `nil != x`
  defp collect_negative_nil_positions({:!=, meta, [_left, nil]}),
    do: [meta[:line]]

  defp collect_negative_nil_positions({:!=, meta, [nil, _right]}),
    do: [meta[:line]]

  # `x !== nil` or `nil !== x`
  defp collect_negative_nil_positions({:!==, meta, [_left, nil]}),
    do: [meta[:line]]

  defp collect_negative_nil_positions({:!==, meta, [nil, _right]}),
    do: [meta[:line]]

  # Recurse through `and`/`or` compound guards so all violations are reported.
  defp collect_negative_nil_positions({:and, _meta, [left, right]}),
    do: collect_negative_nil_positions(left) ++ collect_negative_nil_positions(right)

  defp collect_negative_nil_positions({:or, _meta, [left, right]}),
    do: collect_negative_nil_positions(left) ++ collect_negative_nil_positions(right)

  defp collect_negative_nil_positions(_guard), do: []
end
