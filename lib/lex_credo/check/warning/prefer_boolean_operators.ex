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
      and `!` when **both** operands are clearly boolean-returning — i.e. an
      `is_*` guard call, a comparison operator, a literal boolean, or another
      strict boolean operator.

      Requiring both sides prevents false positives: `and`/`or` raise an
      `ArgumentError` if the *left* operand is not a boolean at runtime, so
      `user && is_nil(user.name)` must not be rewritten as
      `user and is_nil(user.name)` — `user` can be `nil`.

          # BAD — both operands are clearly boolean-returning
          is_binary(x) && is_integer(y)
          is_nil(x) || is_atom(x)
          !is_nil(value)

          # GOOD
          is_binary(x) and is_integer(y)
          is_nil(x) or is_atom(x)
          not is_nil(value)

          # NOT flagged — left side is not boolean-typed; &&/|| is the right tool
          user && user.name
          user && is_nil(user.name)
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
    if boolean_like?(left) and boolean_like?(right) do
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
    if boolean_like?(left) and boolean_like?(right) do
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

  # `&&`/`||` are only considered boolean-like when *both* operands are
  # boolean-like, because the expression can return a non-boolean value
  # (the right operand) when the left is truthy/falsy. Using `and`/`or`
  # in place of a `&&`/`||` whose result may be non-boolean would be
  # misleading even if it compiled.
  defp boolean_like?({:&&, _meta, [left, right]}),
    do: boolean_like?(left) and boolean_like?(right)

  defp boolean_like?({:||, _meta, [left, right]}),
    do: boolean_like?(left) and boolean_like?(right)

  # Literal booleans.
  defp boolean_like?(true), do: true
  defp boolean_like?(false), do: true

  defp boolean_like?(_expr), do: false
end
