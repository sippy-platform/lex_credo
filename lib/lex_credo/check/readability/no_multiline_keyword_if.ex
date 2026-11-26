defmodule LexCredo.Check.Readability.NoMultilineKeywordIf do
  use Credo.Check,
    category: :readability,
    base_priority: :normal,
    param_defaults: [
      exclude_test_files: false,
      macros: [:if, :unless]
    ],
    explanations: [
      check: """
      Only use the keyword form of `if` / `unless` (`if cond, do: a, else: b`)
      when the whole expression fits on one line. Once it spans multiple lines,
      use a `do ... end` block.

      The keyword form exists for short one-liners. When `mix format` has to break
      it up, or it is written over several lines by hand, it reads worse than the
      equivalent block.

          # flagged
          if valid?(changeset),
            do: Repo.insert(changeset),
            else: {:error, changeset}

          # preferred
          if valid?(changeset), do: Repo.insert(changeset), else: {:error, changeset}

          if valid?(changeset) do
            Repo.insert(changeset)
          else
            {:error, changeset}
          end

      The same rule can be applied to other macros that accept a `do:` keyword,
      such as `def`, via the `macros` parameter.
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`.",
        macros:
          "Macros whose keyword `do:` form must stay on one line, e.g. `[:if, :unless, :def, :defp]`. " <>
            "Default: `[:if, :unless]`."
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      macros = Params.get(params, :macros, __MODULE__)
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> SourceFile.source()
      |> Code.string_to_quoted(
        columns: true,
        token_metadata: true,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}}
      )
      |> issues_for(macros, issue_meta)
    end
  end

  defp issues_for({:ok, ast}, macros, issue_meta) do
    {_ast, issues} = Macro.prewalk(ast, [], &traverse(&1, &2, macros, issue_meta))
    Enum.reverse(issues)
  end

  defp issues_for({:error, _error}, _macros, _issue_meta), do: []

  defp traverse({name, meta, [_first | _rest] = args} = ast, issues, macros, issue_meta)
       when is_atom(name) and is_list(meta) do
    if name in macros and keyword_form?(meta, args) and max_line(ast) > meta[:line] do
      {ast, [issue_for(name, meta, issue_meta) | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _macros, _issue_meta), do: {ast, issues}

  defp keyword_form?(meta, args) do
    not Keyword.has_key?(meta, :do) and
      args
      |> List.last()
      |> keyword_with_do?()
  end

  defp keyword_with_do?([_first | _rest] = keyword), do: Enum.any?(keyword, &do_pair?/1)
  defp keyword_with_do?(_last_argument), do: false

  defp do_pair?({{:__block__, _meta, [:do]}, _value}), do: true
  defp do_pair?(_element), do: false

  defp max_line(ast) do
    {_ast, max} =
      Macro.prewalk(ast, 0, fn
        {_name, meta, _args} = node, max when is_list(meta) ->
          {node, Enum.max([max | meta_lines(meta)])}

        node, max ->
          {node, max}
      end)

    max
  end

  defp meta_lines(meta) do
    [meta, meta[:closing], meta[:end]]
    |> Enum.filter(&(is_list(&1) and is_integer(&1[:line])))
    |> Enum.map(& &1[:line])
  end

  defp issue_for(name, meta, issue_meta) do
    format_issue(issue_meta,
      message: "Use a `do ... end` block for `#{name}` when it does not fit on one line.",
      line_no: meta[:line],
      column: meta[:column],
      trigger: Atom.to_string(name)
    )
  end
end
