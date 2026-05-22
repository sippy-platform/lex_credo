defmodule LexCredo.Check.Readability.DocExamplesSection do
  use Credo.Check,
    category: :readability,
    base_priority: :normal,
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
      """
    ]

  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
    |> elem(0)
  end

  # @doc "string" or @doc """..."""  — skip @doc false / @doc nil
  defp traverse({:@, meta, [{:doc, _doc_meta, [doc_string]}]} = ast, {issues, issue_meta})
       when is_binary(doc_string) do
    new_issues =
      if String.contains?(doc_string, "## Examples") do
        []
      else
        [
          format_issue(issue_meta,
            message: "Add a `## Examples` section to this `@doc` string.",
            line_no: meta[:line],
            trigger: "@doc"
          )
        ]
      end

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}
end
