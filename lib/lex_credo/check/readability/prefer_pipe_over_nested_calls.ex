defmodule LexCredo.Check.Readability.PreferPipeOverNestedCalls do
  use Credo.Check,
    category: :readability,
    base_priority: :normal,
    param_defaults: [
      exclude_test_files: false,
      min_pipeline_length: 2,
      excluded_functions: []
    ],
    explanations: [
      check: """
      Use a pipeline instead of passing the result of one function call as the
      first argument of another.

          # flagged
          save(normalize(params))
          String.upcase(String.trim(name))
          format(Map.get(user, :name))

          # preferred
          params |> normalize() |> save()
          name |> String.trim() |> String.upcase()
          user |> Map.get(:name) |> format()

      Unlike Credo's built-in `Credo.Check.Readability.NestedFunctionCalls`, which
      only flags nesting when the outer call is a remote call (`Mod.fun(...)`), this
      check also flags local calls such as `f(g(x))`. Enable one or the other, not
      both, to avoid duplicate issues.

      Special forms and macros (`if`, `case`, `raise`, `assert`, `quote`, operators,
      ...) are never treated as pipeable, an inner call without arguments
      (`f(g())`) has no subject to start a pipeline from, and typespecs and guards
      are not inspected.
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`.",
        min_pipeline_length:
          "Minimum number of nested calls that triggers an issue. `f(g(x))` has a length of 2. " <>
            "Default: `2`.",
        excluded_functions:
          "Function names that are never treated as pipeable, given as strings such as " <>
            "`\"is_nil\"` or `\"Map.get\"`. Default: `[]`."
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @special_forms ~w[
    __block__ __aliases__ __MODULE__ __DIR__ __ENV__ __CALLER__ __STACKTRACE__
    fn & % %{} {} <<>> @ ^ = :: when -> <- \\\\ . .. ..// ... |
    if unless case cond with for try receive quote unquote unquote_splicing
    raise reraise throw super binding
    assert refute assert_receive assert_received refute_receive refute_received assert_raise
    def defp defmacro defmacrop defguard defguardp defmodule defstruct defexception
    defdelegate defimpl defprotocol defoverridable
    import alias require use
    test describe setup setup_all
  ]a

  @typespec_attributes [:type, :typep, :opaque, :spec, :callback, :macrocallback]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      config = %{
        min_length: Params.get(params, :min_pipeline_length, __MODULE__),
        excluded: Params.get(params, :excluded_functions, __MODULE__),
        issue_meta: IssueMeta.for(source_file, params)
      }

      source_file
      |> Credo.Code.ast()
      |> walk([], config)
      |> Enum.reverse()
    end
  end

  defp walk({:@, _meta, [{name, _attribute_meta, _args}]}, issues, _config)
       when name in @typespec_attributes,
       do: issues

  defp walk({:@, _meta, [{_name, _attribute_meta, args}]}, issues, config) when is_list(args),
    do: walk_all(args, issues, config)

  defp walk({:when, _meta, [head | _guards]}, issues, config), do: walk(head, issues, config)

  defp walk({:|>, _meta, [left, right]}, issues, config) do
    issues = walk(left, issues, config)

    case right do
      {_call, _call_meta, args} when is_list(args) -> walk_all(args, issues, config)
      _other -> walk(right, issues, config)
    end
  end

  defp walk({callee, meta, args} = ast, issues, config) when is_list(args) do
    chain = nested_chain(ast, config)

    if length(chain) >= config.min_length do
      issues = [issue_for(meta, callee, config.issue_meta) | issues]
      subject = chain |> List.last() |> first_argument()

      chain
      |> Enum.flat_map(&rest_arguments/1)
      |> walk_all(walk(subject, issues, config), config)
    else
      walk_all([callee | args], issues, config)
    end
  end

  defp walk({left, right}, issues, config), do: walk_all([left, right], issues, config)
  defp walk(list, issues, config) when is_list(list), do: walk_all(list, issues, config)
  defp walk(_leaf, issues, _config), do: issues

  defp walk_all(nodes, issues, config),
    do: Enum.reduce(nodes, issues, &walk(&1, &2, config))

  defp nested_chain(ast, config) do
    if pipeable?(ast, config) do
      [ast | ast |> first_argument() |> nested_chain(config)]
    else
      []
    end
  end

  defp first_argument({_callee, _meta, [first | _rest]}), do: first
  defp rest_arguments({_callee, _meta, [_first | rest]}), do: rest

  defp pipeable?({{:., _dot_meta, [Access, :get]}, _meta, _args}, _config), do: false

  defp pipeable?({{:., _dot_meta, [_module, name]}, meta, [_first | _rest]} = ast, config)
       when is_atom(name) do
    not Keyword.get(meta, :no_parens, false) and
      not Keyword.get(meta, :from_interpolation, false) and
      function_name(ast) not in config.excluded
  end

  defp pipeable?({name, _meta, [_first | _rest] = args} = ast, config) when is_atom(name) do
    name not in @special_forms and
      not Macro.operator?(name, length(args)) and
      not (name |> Atom.to_string() |> String.starts_with?("sigil_")) and
      function_name(ast) not in config.excluded
  end

  defp pipeable?(_ast, _config), do: false

  defp function_name({{:., _dot_meta, [module, name]}, _meta, _args}),
    do: "#{module_name(module)}.#{name}"

  defp function_name({name, _meta, _args}), do: Atom.to_string(name)

  defp module_name({:__aliases__, _meta, parts}), do: Enum.map_join(parts, ".", &to_string/1)
  defp module_name({:__MODULE__, _meta, _context}), do: "__MODULE__"
  defp module_name(module) when is_atom(module), do: inspect(module)
  defp module_name(_module), do: "?"

  defp issue_for(meta, callee, issue_meta) do
    format_issue(issue_meta,
      message: "Use a pipeline instead of nested function calls.",
      line_no: meta[:line],
      column: meta[:column],
      trigger: trigger(callee)
    )
  end

  defp trigger({:., _meta, [module, name]}), do: "#{module_name(module)}.#{name}"
  defp trigger(name) when is_atom(name), do: Atom.to_string(name)
end
