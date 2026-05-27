defmodule LexCredo.Check.Warning.NonBooleanWithStrictOperator do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Use `&&`/`||`/`!` instead of `and`/`or`/`not` when an operand is clearly non-boolean.

      The strict boolean operators `and`, `or`, and `not` raise an `ArgumentError` at
      runtime if the left operand is not exactly `true` or `false`. They also signal to
      readers that the expression is purely boolean. When an operand is a struct field
      access (without a `?` suffix), a non-boolean literal, or `nil`, using `and`/`or`/`not`
      will either crash at runtime or silently mislead — `&&`/`||`/`!` are the correct
      operators for truthy/falsy short-circuit logic.

      This check is the complement of `PreferBooleanOperators`, which flags `&&`/`||`/`!`
      when both operands are clearly boolean.

          # BAD — right side returns an ID (non-boolean); use &&
          Enum.find_value(accounts, &(&1.extension.exten == number and &1.id))

          # BAD — left side is a string field that can be nil; and raises at runtime
          user.name and is_valid?(user)

          # BAD — not requires a boolean argument; use !
          not user.name

          # GOOD
          &1.extension.exten == number && &1.id
          user.name && is_valid?(user)
          !user.name

          # NOT flagged — ?-suffixed field follows Elixir's boolean-returning convention
          user.active? and is_admin?(user)

          # NOT flagged — plain variables; type cannot be determined statically
          a and b

          # NOT flagged — module-qualified call; return type unknown
          MyModule.fetch() and condition
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

  # Module-qualified calls (Map.new(), Enum.count(list), etc.) — return type unknown;
  # must come before the field-access clause because module references use the same
  # dot-call AST shape.
  defp clearly_non_boolean?({{:., _, [{:__aliases__, _, _}, _]}, _, _}), do: false

  # Field/property access where the field name does NOT end with `?`.
  # Elixir convention: a `?` suffix signals a boolean-returning function/field.
  # Covers: user.name, &1.id, record.exten, but NOT user.active? or user.valid?.
  defp clearly_non_boolean?({{:., _, [_receiver, field]}, _, []})
       when is_atom(field),
       do: not String.ends_with?(Atom.to_string(field), "?")

  # Non-boolean literals: integers, floats, and strings are never booleans.
  defp clearly_non_boolean?(x) when is_integer(x) or is_float(x) or is_binary(x), do: true

  # Non-boolean atoms: nil, :ok, :error, and any other atom that is not true/false.
  defp clearly_non_boolean?(x) when is_atom(x) and x != true and x != false, do: true

  # Everything else (plain variables, user-defined calls, comparisons, etc.):
  # type cannot be determined statically, so we do not flag.
  defp clearly_non_boolean?(_), do: false
end
