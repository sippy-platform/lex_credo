defmodule LexCredo.Check.Warning.NonBooleanWithStrictOperator do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Use `&&`/`||`/`!` instead of `and`/`or`/`not` when an operand is a
      clearly non-boolean value.

      The strict boolean operators raise an `ArgumentError` at runtime if the
      left operand is not exactly `true` or `false`. When an operand is a
      non-boolean literal (integer, float, string) or a non-boolean atom such
      as `nil`, `:ok`, or `:error`, the expression is truthy/falsy short-circuit
      logic and `&&`/`||`/`!` are the correct operators.

      This check is intentionally narrow: struct field accesses (e.g.
      `user.active`) and unknown function calls are **not** flagged because
      their types cannot be determined statically, and boolean fields without
      a `?` suffix are common in Elixir (e.g. Ecto schemas).

      This check is the complement of `PreferBooleanOperators`, which flags
      `&&`/`||`/`!` when both operands are clearly boolean.

          # BAD — right operand is a non-boolean atom; and/or raises or misleads
          process(data) and :ok
          result or :error

          # BAD — string used as a fallback with or; use ||
          env_var or "default"

          # BAD — not requires a boolean argument; nil/atoms are not booleans
          not nil

          # GOOD
          process(data) && :ok
          result || :error
          env_var || "default"
          !nil

          # NOT flagged — field access; type cannot be determined statically
          # (user.active is a common boolean field pattern in Ecto schemas)
          user.active and is_admin?(user)
          exten == number and record.id
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`."
      ]
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @strict_ops [:and, :or]

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

  defp traverse({op, meta, [left, right]} = ast, {issues, issue_meta})
       when op in @strict_ops do
    if clearly_non_boolean?(left) or clearly_non_boolean?(right) do
      {replacement, word} =
        case op do
          :and -> {"&&", "and"}
          :or -> {"||", "or"}
        end

      issue =
        format_issue(issue_meta,
          message:
            "Use `#{replacement}` instead of `#{word}` when an operand is not a boolean expression.",
          line_no: meta[:line],
          trigger: word
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse({:not, meta, [expr]} = ast, {issues, issue_meta}) do
    if clearly_non_boolean?(expr) do
      issue =
        format_issue(issue_meta,
          message: "Use `!` instead of `not` when the operand is not a boolean expression.",
          line_no: meta[:line],
          trigger: "not"
        )

      {ast, {[issue | issues], issue_meta}}
    else
      {ast, {issues, issue_meta}}
    end
  end

  defp traverse(ast, acc), do: {ast, acc}

  # Non-boolean literals: integers, floats, and strings are never booleans.
  defp clearly_non_boolean?(x) when is_integer(x) or is_float(x) or is_binary(x), do: true

  # Non-boolean atoms: nil, :ok, :error, and any other atom that is not true/false.
  defp clearly_non_boolean?(x) when is_atom(x) and x != true and x != false, do: true

  # Everything else (variables, function calls, field accesses, comparisons, etc.):
  # type cannot be determined statically, so we do not flag. In particular,
  # struct field accesses such as `user.active` are left alone — boolean fields
  # without a `?` suffix are common in Elixir (e.g. Ecto schemas).
  defp clearly_non_boolean?(_expr), do: false
end
