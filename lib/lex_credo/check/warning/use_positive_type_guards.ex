defmodule LexCredo.Check.Warning.UsePositiveTypeGuards do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      Use positive type guards instead of negated type checks in function guards.

      Negating a type guard is imprecise — `not is_nil(x)` passes integers, lists,
      and anything else that is not nil. `not is_binary(x)` passes nil, integers,
      atoms, and more. State what you expect, not what you want to exclude.

          # BAD: passes any non-nil value, including integers, lists, etc.
          def call_service(%{req: req}) when not is_nil(req), do: ...
          def call_service(%{req: req}) when req != nil, do: ...

          # BAD: passes nil, integers, atoms, …
          def validate(x) when not is_binary(x), do: ...

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

  # All built-in type-checking guard functions.
  @type_guard_fns ~w[
    is_nil is_binary is_atom is_integer is_float is_number
    is_list is_map is_tuple is_function is_pid is_port
    is_reference is_bitstring is_boolean is_struct is_exception
    is_map_key
  ]a

  # Match `def`/`defp` with a `when` guard in the function head.
  defp traverse(
         {def_type, _def_meta, [{:when, when_meta, [_head, guard]} | _body]} = ast,
         {issues, issue_meta}
       )
       when def_type in [:def, :defp] do
    new_issues =
      guard
      |> collect_negated_type_guard_positions()
      |> Enum.map(fn {line, trigger} ->
        format_issue(issue_meta,
          message:
            "Use a positive type guard instead of a negated one (`#{trigger}`). " <>
              "State what you expect rather than what you want to exclude.",
          line_no: line || when_meta[:line],
          trigger: trigger
        )
      end)

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  # `not is_*(x)` — any negated type guard
  defp collect_negated_type_guard_positions({:not, meta, [{guard_fn, _guard_meta, _guard_args}]})
       when guard_fn in @type_guard_fns,
       do: [{meta[:line], "not #{guard_fn}"}]

  # `x != nil` or `nil != x`
  defp collect_negated_type_guard_positions({:!=, meta, [_left, nil]}),
    do: [{meta[:line], "!= nil"}]

  defp collect_negated_type_guard_positions({:!=, meta, [nil, _right]}),
    do: [{meta[:line], "!= nil"}]

  # `x !== nil` or `nil !== x`
  defp collect_negated_type_guard_positions({:!==, meta, [_left, nil]}),
    do: [{meta[:line], "!== nil"}]

  defp collect_negated_type_guard_positions({:!==, meta, [nil, _right]}),
    do: [{meta[:line], "!== nil"}]

  # Recurse through `and`/`or` compound guards so all violations are reported.
  defp collect_negated_type_guard_positions({:and, _meta, [left, right]}),
    do:
      collect_negated_type_guard_positions(left) ++
        collect_negated_type_guard_positions(right)

  defp collect_negated_type_guard_positions({:or, _meta, [left, right]}),
    do:
      collect_negated_type_guard_positions(left) ++
        collect_negated_type_guard_positions(right)

  defp collect_negated_type_guard_positions(_guard), do: []
end
