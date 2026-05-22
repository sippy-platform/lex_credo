defmodule LexCredo.Check.Warning.PreferBooleanOperators do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Use `and`/`or`/`not` instead of `&&`/`||`/`!` when operands are booleans.

      The strict boolean operators make intent clear and catch accidental truthy
      values (e.g. `:undefined` from Erlang APIs). This check flags `&&`, `||`,
      and `!` when at least one operand is clearly boolean-returning — i.e. an
      `is_*` guard call, a comparison operator, or another boolean operator.

          # BAD — operands are boolean-typed
          is_binary(x) && is_integer(y)
          has_permission?(user) || is_admin?(user)
          !is_nil(value)

          # GOOD
          is_binary(x) and is_integer(y)
          has_permission?(user) or is_admin?(user)
          not is_nil(value)

          # NOT flagged — truthy/falsy short-circuit idiom, not boolean-typed
          user && user.name
          config[:timeout] || 5_000
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`."
      ]
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

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
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)

      Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
      |> elem(0)
    end
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

  # `not`/`!`/`and`/`or` are strict boolean operators — they always return a boolean.
  defp boolean_like?({op, _meta, _args}) when op in [:not, :!, :and, :or], do: true

  # `&&`/`||` are truthy/falsy short-circuit operators; they are only boolean-like
  # when at least one of their operands is boolean-like. This avoids flagging
  # idiomatic truthy patterns like `(user && user.name) || "default"`.
  defp boolean_like?({:&&, _meta, [left, right]}),
    do: boolean_like?(left) or boolean_like?(right)

  defp boolean_like?({:||, _meta, [left, right]}),
    do: boolean_like?(left) or boolean_like?(right)

  # Literal booleans.
  defp boolean_like?(true), do: true
  defp boolean_like?(false), do: true

  defp boolean_like?(_expr), do: false
end
