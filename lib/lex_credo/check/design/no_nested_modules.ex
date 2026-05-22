defmodule LexCredo.Check.Design.NoNestedModules do
  use Credo.Check,
    category: :design,
    base_priority: :high,
    param_defaults: [exclude_test_files: true],
    explanations: [
      check: """
      Do not nest module definitions inside other modules.

      Nested modules can cause cyclic dependencies and compilation errors.
      Each module should live in its own file.

      # BAD
      defmodule Outer do
        defmodule Inner do
          # ...
        end
      end

      # GOOD — separate files, separate modules
      defmodule Outer do
        # ...
      end

      defmodule Outer.Inner do
        # ...
      end
      """,
      params: [
        exclude_test_files:
          "When `true`, skips test files. Default: `true`. " <>
            "Set to `false` to also flag nested modules in test helpers."
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

  # When visiting a defmodule, flag any defmodule that appears as an immediate
  # child in the body — this avoids depth-counter drift with prewalk-only traversal
  # while still producing one issue per nested module (further nesting is caught
  # when prewalk visits the inner defmodule in subsequent steps).
  defp traverse({:defmodule, _outer_meta, [_name, [do: body]]} = ast, {issues, issue_meta}) do
    new_issues =
      body
      |> immediate_defmodules()
      |> Enum.map(fn {:defmodule, meta, _children} ->
        format_issue(issue_meta,
          message: "Do not nest module definitions. Move `defmodule` to its own file instead.",
          line_no: meta[:line]
        )
      end)

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  # A `__block__` body can hold multiple top-level statements.
  defp immediate_defmodules({:__block__, _meta, stmts}),
    do: Enum.filter(stmts, &match?({:defmodule, _dm_meta, _dm_children}, &1))

  # A single-statement body that is itself a defmodule.
  defp immediate_defmodules({:defmodule, _meta, _children} = dm), do: [dm]

  defp immediate_defmodules(_body), do: []
end
