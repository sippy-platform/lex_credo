defmodule LexCredo.Check.Refactor.NoEnumWrapperFunctions do
  use Credo.Check,
    category: :refactor,
    base_priority: :normal,
    explanations: [
      check: """
      Avoid writing named functions whose body is only a call to `Enum.*` or
      `Stream.*`.

      Such wrappers hide the collection structure, coupling the function to one
      call-site shape and preventing reuse in `Stream`, `Task.async_stream`, or
      comprehensions. Instead, write a function that operates on a single item
      and compose it with `Enum`/`Stream` at the call site.

          # BAD — parse_items/1 is only usable with a list
          def parse_items(list), do: Enum.map(list, &String.to_integer/1)

          # GOOD — parse_item/1 is reusable anywhere; caller composes with Enum
          defp parse_item(item), do: String.to_integer(item)
          collection |> Enum.map(&parse_item/1)
      """
    ]

  alias Credo.IssueMeta

  # Transformation functions that have a clear single-item equivalent.
  # Aggregation/predicate functions (any?, all?, count, sum, etc.) are
  # inherently collection-level operations and are excluded intentionally.
  @enum_fns ~w[map flat_map each map_reduce flat_map_reduce scan]a

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
    |> elem(0)
  end

  defp traverse(
         {def_type, meta, [_head, [{:do, body}]]} = ast,
         {issues, issue_meta}
       )
       when def_type in [:def, :defp] do
    actual_body = unwrap_block(body)

    if enum_or_stream_call?(actual_body) do
      issue =
        format_issue(issue_meta,
          message:
            "Avoid wrapping `Enum`/`Stream` calls in a named function. " <>
              "Write a single-item function and compose with `Enum` at the call site.",
          line_no: meta[:line],
          trigger: "def"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse(ast, acc), do: {ast, acc}

  # A single-expression block unwraps transparently.
  defp unwrap_block({:__block__, _, [single_expr]}), do: single_expr
  # A multi-expression block is never a simple wrapper.
  defp unwrap_block({:__block__, _, _multiple}), do: :multiple_expressions
  defp unwrap_block(expr), do: expr

  # Enum.fun/n or Stream.fun/n calls
  defp enum_or_stream_call?({{:., _, [{:__aliases__, _, [mod]}, fun]}, _, _args})
       when mod in [:Enum, :Stream] and fun in @enum_fns,
       do: true

  defp enum_or_stream_call?(_), do: false
end
