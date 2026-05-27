defmodule LexCredo.Check.Readability.DocExamplesSection do
  use Credo.Check,
    category: :readability,
    base_priority: :normal,
    param_defaults: [
      exclude_test_files: false,
      skip_def_types: [:defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]
    ],
    explanations: [
      check: """
      Every `@doc` string on a public function should include a `## Examples` section.

      Examples are the fastest way for a reader to understand what a function does.
      Use `iex>` doctests for deterministic output; use a plain code block when the
      result depends on runtime state.

          # BAD — no Examples section
          @doc \"""
          Adds two numbers.
          \"""
          def add(a, b), do: a + b

          # GOOD
          @doc \"""
          Adds two numbers.

          ## Examples

              iex> MyModule.add(1, 2)
              3

          \"""
          def add(a, b), do: a + b

      Definitions listed in `skip_def_types` (macros, guards, private functions, and
      delegates by default) are exempt from this requirement because they are less
      amenable to illustrative `iex>` examples.
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`.",
        skip_def_types: """
        Definition types that do not require a `## Examples` section.
        Defaults to `[:defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]`.
        """
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  # All definition-like forms whose presence after a @doc should consume the
  # pending-doc state (whether we flag it or not).
  @all_def_types [:def, :defp, :defmacro, :defmacrop, :defguard, :defguardp, :defdelegate]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      skip_def_types = Params.get(params, :skip_def_types, __MODULE__)

      source_file
      |> Credo.Code.prewalk(&traverse(&1, &2, skip_def_types), {[], nil, issue_meta})
      |> elem(0)
    end
  end

  # @doc "string" — store as pending; we'll decide whether to flag it once we
  # see which definition type follows.
  defp traverse(
         {:@, meta, [{:doc, _doc_meta, [doc_string]}]} = ast,
         {issues, _pending, issue_meta},
         _skip_def_types
       )
       when is_binary(doc_string) do
    {ast, {issues, {meta[:line], doc_string}, issue_meta}}
  end

  # @doc false / @doc nil — clear pending without flagging.
  defp traverse(
         {:@, _meta, [{:doc, _doc_meta, [_doc_value]}]} = ast,
         {issues, _pending, issue_meta},
         _skip_def_types
       ) do
    {ast, {issues, nil, issue_meta}}
  end

  # Any recognised definition form — resolve the pending @doc.
  # If the def type is not in the skip list, flag missing examples.
  defp traverse(
         {def_type, _meta, [head | _rest]} = ast,
         {issues, pending, issue_meta},
         skip_def_types
       )
       when def_type in @all_def_types do
    new_issues =
      if def_type in skip_def_types do
        []
      else
        case def_name_arity(head) do
          {name, arity} -> check_pending_doc(pending, name, arity, issue_meta)
          nil -> []
        end
      end

    {ast, {new_issues ++ issues, nil, issue_meta}}
  end

  defp traverse(ast, acc, _skip_def_types), do: {ast, acc}

  # Extract {name, arity} from a function head, handling `when` guards.
  defp def_name_arity({:when, _meta, [head | _guards]}), do: def_name_arity(head)
  defp def_name_arity({name, _meta, args}) when is_atom(name), do: {name, length(args || [])}
  defp def_name_arity(_head), do: nil

  defp check_pending_doc(nil, _name, _arity, _issue_meta), do: []

  defp check_pending_doc({line_no, doc}, name, arity, issue_meta) do
    if String.contains?(doc, "## Examples") do
      []
    else
      [
        format_issue(issue_meta,
          message: "Add a `## Examples` section to the `@doc` for `#{name}/#{arity}`.",
          line_no: line_no,
          trigger: "@doc"
        )
      ]
    end
  end
end
