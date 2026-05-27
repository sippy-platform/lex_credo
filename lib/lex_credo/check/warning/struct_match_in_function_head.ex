defmodule LexCredo.Check.Warning.StructMatchInFunctionHead do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Match struct parameters in the function head, not in the body.

      Destructuring a parameter as a struct at the top of a function body hides
      the expected type from both the reader and Elixir's type system. Declaring
      the struct in the function head makes the contract visible at a glance,
      enables multi-clause specialisation, and allows the type checker to infer
      the parameter type directly from the signature.

          # BAD — struct type is hidden inside the body; type checker cannot
          #        infer that `data` must be a %User{}
          def process(data) do
            %User{name: name, email: email} = data
            send_welcome(name, email)
          end

          # GOOD — type is visible in the signature
          def process(%User{name: name, email: email}) do
            send_welcome(name, email)
          end

          # GOOD — keep the original binding when you need the whole struct
          def process(%User{name: name, email: email} = data) do
            send_welcome(name, email)
            audit_log(data)
          end

      Only top-level statements in the function body are checked. Struct matches
      that appear inside `case`, `cond`, `if`, `with`, or anonymous functions are
      left alone because they often serve a different purpose.
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`."
      ]
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

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

  defp traverse(
         {def_type, _meta, [head, [{:do, body}]]} = ast,
         {issues, issue_meta}
       )
       when def_type in [:def, :defp] do
    param_names = plain_param_names(head)

    new_issues =
      if param_names == [] do
        []
      else
        param_set = MapSet.new(param_names)

        body
        |> top_level_stmts()
        |> Enum.flat_map(&check_stmt(&1, param_set, issue_meta))
      end

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  # Strip an optional `when` guard to reach the actual function head.
  defp plain_param_names({:when, _meta, [actual_head | _guards]}),
    do: plain_param_names(actual_head)

  defp plain_param_names({_fn_name, _meta, args}) when is_list(args),
    do: Enum.flat_map(args, &extract_variable/1)

  defp plain_param_names(_), do: []

  # Plain variable: `def f(x)` → x
  defp extract_variable({name, _meta, nil})
       when is_atom(name) and name != :_,
       do: [name]

  # Variable with a default: `def f(x \\ nil)` → x
  defp extract_variable({:\\, _meta, [{name, _vm, nil}, _default]})
       when is_atom(name) and name != :_,
       do: [name]

  # Everything else (tuple patterns, map patterns, literals, …) — skip.
  defp extract_variable(_), do: []

  # Multi-expression body — examine each statement in order.
  defp top_level_stmts({:__block__, _meta, stmts}), do: stmts
  # Single-expression body (inline `do:` or a one-liner `do...end`).
  defp top_level_stmts(single), do: [single]

  # `%Struct{…} = param` — the pattern form we want to move to the head.
  defp check_stmt({:=, meta, [pattern, {var_name, _vm, nil}]}, param_set, issue_meta)
       when is_atom(var_name) do
    with name when name != nil <- struct_name(pattern),
         true <- MapSet.member?(param_set, var_name) do
      [
        format_issue(issue_meta,
          message:
            "Match `%#{name}{}` against `#{var_name}` in the function head instead of the body.",
          line_no: meta[:line],
          trigger: "="
        )
      ]
    else
      _ -> []
    end
  end

  defp check_stmt(_stmt, _param_set, _issue_meta), do: []

  # `%Alias.Module{}` — standard aliased struct.
  defp struct_name({:%, _meta, [{:__aliases__, _am, mod_parts}, {:%{}, _mm, _fields}]}),
    do: mod_parts |> Enum.map(&Atom.to_string/1) |> Enum.join(".")

  # `%__MODULE__{}` — current-module reference.
  defp struct_name({:%, _meta, [{:__MODULE__, _mm, _ctx}, {:%{}, _mm2, _fields}]}),
    do: "__MODULE__"

  # `%_{}` — matches any struct (wildcard module).
  defp struct_name({:%, _meta, [{:_, _mm, nil}, {:%{}, _mm2, _fields}]}),
    do: "_"

  # Plain map `%{}` or anything else — not a named struct.
  defp struct_name(_), do: nil
end
