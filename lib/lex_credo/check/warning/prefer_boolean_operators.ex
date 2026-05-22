defmodule LexCredo.Check.Warning.PreferBooleanOperators do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    explanations: [
      check: """
      Use `and`/`or`/`not` instead of `&&`/`||`/`!` when operands are booleans.

      The strict boolean operators make intent clear and catch accidental truthy
      values (e.g. `:undefined` from Erlang APIs). This check flags `&&`, `||`,
      and `!` when at least one operand is clearly boolean-returning — i.e. an
      `is_*` guard call, a comparison operator, or another boolean operator.

          # PREFER
          if is_binary(name) and is_integer(age), do: ...
          unless is_nil(x) or is_nil(y), do: ...

          # OVER
          if is_binary(name) && is_integer(age), do: ...
          unless is_nil(x) || is_nil(y), do: ...
      """
    ]

  alias Credo.IssueMeta

  # Guard functions that always return a boolean.
  @boolean_guard_fns ~w[
    is_nil is_binary is_atom is_integer is_float is_number
    is_list is_map is_tuple is_function is_pid is_port
    is_reference is_bitstring is_boolean is_struct is_exception
    is_map_key
  ]a

  # Operators whose result is always a boolean.
  @comparison_ops ~w[== != < > <= >= === !==]a

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
    |> elem(0)
  end

  defp traverse({:&&, meta, [left, right]} = ast, {issues, issue_meta}) do
    if boolean_like?(left) or boolean_like?(right) do
      issue =
        format_issue(issue_meta,
          message: "Use `and` instead of `&&` when operands are boolean expressions.",
          line_no: meta[:line],
          trigger: "&&"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse({:||, meta, [left, right]} = ast, {issues, issue_meta}) do
    if boolean_like?(left) or boolean_like?(right) do
      issue =
        format_issue(issue_meta,
          message: "Use `or` instead of `||` when operands are boolean expressions.",
          line_no: meta[:line],
          trigger: "||"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse({:!, meta, [expr]} = ast, {issues, issue_meta}) do
    if boolean_like?(expr) do
      issue =
        format_issue(issue_meta,
          message: "Use `not` instead of `!` when the operand is a boolean expression.",
          line_no: meta[:line],
          trigger: "!"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse(ast, acc), do: {ast, acc}

  # An `is_*` guard call always returns a boolean.
  defp boolean_like?({fun, _meta, _args}) when fun in @boolean_guard_fns, do: true

  # Comparison operators always return a boolean.
  defp boolean_like?({op, _meta, [_left, _right]}) when op in @comparison_ops, do: true

  # `not`/`!`/`and`/`or`/`&&`/`||` all produce booleans (or truthy/falsy).
  defp boolean_like?({op, _meta, _operands}) when op in [:not, :!, :and, :or, :&&, :||], do: true

  # Literal booleans.
  defp boolean_like?(true), do: true
  defp boolean_like?(false), do: true

  defp boolean_like?(_expr), do: false
end
