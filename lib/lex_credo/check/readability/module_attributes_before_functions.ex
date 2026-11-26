defmodule LexCredo.Check.Readability.ModuleAttributesBeforeFunctions do
  use Credo.Check,
    category: :readability,
    base_priority: :normal,
    param_defaults: [
      exclude_test_files: false,
      allowed_attributes: []
    ],
    explanations: [
      check: """
      Declare types (`@type`, `@typep`, `@opaque`, `@typedoc`), callbacks, and constant module
      attributes at the top of the module, before the first function definition.

      Types and constants scattered between functions are hard to find and make
      it unclear which parts of the module they apply to. Keeping them at the top
      gives readers the module's vocabulary before its behaviour.

          # flagged
          defmodule MyApp.Worker do
            def run(job), do: process(job, @timeout)

            @type job :: map()
            @timeout 5_000

            defp process(job, timeout), do: {job, timeout}
          end

          # preferred
          defmodule MyApp.Worker do
            @type job :: map()

            @timeout 5_000

            def run(job), do: process(job, @timeout)

            defp process(job, timeout), do: {job, timeout}
          end

      Attributes that annotate the next function are allowed anywhere: `@doc`,
      `@spec`, `@impl`, `@deprecated`, `@dialyzer`, `@compile`, and `@decorate`,
      as well as ExUnit's `@tag`, `@describetag`, and `@moduletag`. Add your own
      (for example DSL attributes such as Absinthe's `@desc`) via
      `allowed_attributes`.
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`.",
        allowed_attributes:
          "Additional attribute names (atoms) that may appear after function definitions. " <>
            "Default: `[]`."
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @function_definitions [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]
  @type_attributes [:type, :typep, :opaque, :typedoc, :callback, :macrocallback]
  @function_attributes [
    :doc,
    :spec,
    :impl,
    :deprecated,
    :dialyzer,
    :compile,
    :decorate,
    :tag,
    :describetag,
    :moduletag
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      allowed = @function_attributes ++ Params.get(params, :allowed_attributes, __MODULE__)
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, allowed, issue_meta), [])
      |> Enum.reverse()
    end
  end

  defp traverse({:defmodule, _meta, [_alias, [do: body]]} = ast, issues, allowed, issue_meta) do
    {ast, module_issues(body, allowed, issue_meta) ++ issues}
  end

  defp traverse(ast, issues, _allowed, _issue_meta), do: {ast, issues}

  defp module_issues(body, allowed, issue_meta) do
    {issues, _seen_function?} =
      body
      |> statements()
      |> Enum.reduce({[], false}, fn statement, {issues, seen_function?} ->
        cond do
          function_definition?(statement) ->
            {issues, true}

          seen_function? and misplaced_attribute?(statement, allowed) ->
            {[issue_for(statement, issue_meta) | issues], seen_function?}

          true ->
            {issues, seen_function?}
        end
      end)

    issues
  end

  defp statements({:__block__, _meta, statements}), do: statements
  defp statements(statement), do: [statement]

  defp function_definition?({name, _meta, args}) when is_list(args),
    do: name in @function_definitions

  defp function_definition?(_statement), do: false

  defp misplaced_attribute?({:@, _meta, [{name, _attribute_meta, [_value | _rest]}]}, allowed)
       when is_atom(name),
       do: name not in allowed

  defp misplaced_attribute?(_statement, _allowed), do: false

  defp issue_for({:@, meta, [{name, _attribute_meta, _value}]}, issue_meta) do
    kind = if name in @type_attributes, do: "Type", else: "Module attribute"

    format_issue(issue_meta,
      message:
        "#{kind} `@#{name}` should be declared at the top of the module, before any function.",
      line_no: meta[:line],
      trigger: "@#{name}"
    )
  end
end
