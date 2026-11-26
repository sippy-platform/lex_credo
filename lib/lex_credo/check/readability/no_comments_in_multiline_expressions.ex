defmodule LexCredo.Check.Readability.NoCommentsInMultilineExpressions do
  use Credo.Check,
    category: :readability,
    base_priority: :normal,
    param_defaults: [
      exclude_test_files: false,
      kinds: [:pipe, :map, :keyword]
    ],
    explanations: [
      check: """
      Do not put comments in between the steps of a multi-line pipeline or the
      entries of a multi-line map, struct, or keyword list.

      Comments wedged between pipe steps or map keys break the visual flow of
      the expression and usually narrate what the code already says. If a step
      needs explaining, extract it into a well-named function; if a value needs
      explaining, give it a name or document it in `@moduledoc` / `@doc`.

          # flagged
          params
          # normalise the input first
          |> normalize()
          # then persist
          |> save()

          %{
            # the display name
            name: name,
            age: age
          }

          # preferred
          params
          |> normalize()
          |> save()

      Comments inside an anonymous function or `do ... end` block nested in the
      expression are not flagged, nor are `credo:` directives.
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`.",
        kinds:
          "Which multi-line expressions to inspect. Any of `:pipe`, `:map` (maps and structs), " <>
            "and `:keyword` (bracketed keyword lists). Default: `[:pipe, :map, :keyword]`."
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @labels %{
    pipe: "a multi-line pipeline",
    map: "a multi-line map",
    keyword: "a multi-line keyword list"
  }

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      kinds = Params.get(params, :kinds, __MODULE__)
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> SourceFile.source()
      |> Code.string_to_quoted_with_comments(
        columns: true,
        token_metadata: true,
        literal_encoder: &{:ok, {:__block__, &2, [&1]}}
      )
      |> issues_for(kinds, issue_meta)
    end
  end

  defp issues_for({:ok, ast, comments}, kinds, issue_meta) do
    ranges = collect_ranges(ast)

    comments
    |> Enum.reject(&directive?/1)
    |> Enum.flat_map(&issue_for_comment(&1, ranges, kinds, issue_meta))
  end

  defp issues_for({:error, _error}, _kinds, _issue_meta), do: []

  defp directive?(%{text: text}), do: text =~ ~r/^#\s*credo:/

  defp issue_for_comment(%{line: line, column: column} = comment, ranges, kinds, issue_meta) do
    innermost =
      ranges
      |> Enum.filter(&contains?(&1, line, column))
      |> Enum.max_by(&{&1.start_line, &1.start_column}, fn -> nil end)

    case innermost do
      %{kind: kind} -> if kind in kinds, do: [issue(issue_meta, comment, kind)], else: []
      _not_flagged -> []
    end
  end

  defp issue(issue_meta, %{line: line, column: column, text: text}, kind) do
    format_issue(issue_meta,
      message:
        "Avoid comments inside #{@labels[kind]}. Extract a named function or " <>
          "document the intent elsewhere.",
      line_no: line,
      column: column,
      trigger: text
    )
  end

  defp contains?(range, line, column) do
    {line, column} > {range.start_line, range.start_column} and
      (line < range.end_line or (range.inclusive_end and line == range.end_line))
  end

  defp collect_ranges(ast) do
    {_ast, ranges} = Macro.prewalk(ast, [], &collect/2)
    ranges
  end

  defp collect({:|>, _meta, _args} = pipe, ranges) do
    chain = pipe_chain(pipe)
    {start_line, start_column} = start_position(chain)
    end_line = max_line(chain)

    ranges =
      if end_line > start_line do
        [range(:pipe, start_line, start_column, end_line, true) | ranges]
      else
        ranges
      end

    {chain_children(pipe), ranges}
  end

  defp collect({:%{}, meta, _pairs} = ast, ranges) do
    {ast, maybe_bracket_range(:map, meta, ranges)}
  end

  defp collect({:__block__, meta, [[_first | _rest] = list]} = ast, ranges) do
    if Enum.all?(list, &keyword_pair?/1) do
      {ast, maybe_bracket_range(:keyword, meta, ranges)}
    else
      {ast, ranges}
    end
  end

  defp collect({:fn, meta, _clauses} = ast, ranges) do
    {ast, maybe_exempt_range(meta, meta[:closing], ranges)}
  end

  defp collect({_name, meta, _args} = ast, ranges) when is_list(meta) do
    if meta[:do] && meta[:end] do
      {ast, maybe_exempt_range(meta[:do], meta[:end], ranges)}
    else
      {ast, ranges}
    end
  end

  defp collect(ast, ranges), do: {ast, ranges}

  defp keyword_pair?({{:__block__, meta, [key]}, _value}) when is_atom(key),
    do: meta[:format] == :keyword

  defp keyword_pair?(_element), do: false

  defp maybe_bracket_range(kind, meta, ranges) do
    with closing when is_list(closing) <- meta[:closing],
         true <- closing[:line] > meta[:line] do
      [range(kind, meta[:line], meta[:column], closing[:line], false) | ranges]
    else
      _not_multiline -> ranges
    end
  end

  defp maybe_exempt_range(start_meta, end_meta, ranges)
       when is_list(start_meta) and is_list(end_meta) do
    [range(:exempt, start_meta[:line], start_meta[:column], end_meta[:line], false) | ranges]
  end

  defp maybe_exempt_range(_start_meta, _end_meta, ranges), do: ranges

  defp range(kind, start_line, start_column, end_line, inclusive_end) do
    %{
      kind: kind,
      start_line: start_line,
      start_column: start_column || 0,
      end_line: end_line,
      inclusive_end: inclusive_end
    }
  end

  defp pipe_chain({:|>, _meta, [left, _right]} = pipe), do: [pipe | pipe_chain(left)]
  defp pipe_chain(_operand), do: []

  defp chain_children({:|>, _meta, [left, right]}),
    do: {:__block__, [], [chain_children(left), right]}

  defp chain_children(operand), do: operand

  defp start_position(chain) do
    chain
    |> List.last()
    |> positions()
    |> Enum.min()
  end

  defp max_line(chain) do
    chain
    |> hd()
    |> positions()
    |> Enum.map(&elem(&1, 0))
    |> Enum.max()
  end

  defp positions(ast) do
    {_ast, positions} =
      Macro.prewalk(ast, [], fn
        {_name, meta, _args} = node, acc when is_list(meta) ->
          {node, meta_positions(meta) ++ acc}

        node, acc ->
          {node, acc}
      end)

    positions
  end

  defp meta_positions(meta) do
    [meta, meta[:closing], meta[:end]]
    |> Enum.filter(&(is_list(&1) and is_integer(&1[:line])))
    |> Enum.map(&{&1[:line], &1[:column] || 0})
  end
end
