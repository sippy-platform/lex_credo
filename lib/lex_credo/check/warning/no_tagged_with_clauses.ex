defmodule LexCredo.Check.Warning.NoTaggedWithClauses do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Do not use tagged-tuple workarounds in `with` clauses to identify which
      clause failed in the `else` block.

      If you need to distinguish between different failure sources, use `case`
      instead. If you do not need to distinguish, normalise error return types
      in small private helper functions.

          # BAD — tags exist only to tell apart which step failed
          with {:user, {:ok, user}} <- {:user, fetch_user(id)},
               {:post, {:ok, post}} <- {:post, fetch_post(user)} do
            {:ok, post}
          else
            {:user, {:error, reason}} -> {:error, {:user, reason}}
            {:post, {:error, reason}} -> {:error, {:post, reason}}
          end

          # GOOD — each function returns a distinct error atom,
          # so the step that failed is clear without wrapping tuples
          with {:ok, user} <- fetch_user(id),
               {:ok, post} <- fetch_post(user) do
            {:ok, post}
          else
            {:error, :user_not_found} = err -> err
            {:error, :post_not_found} = err -> err
          end
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

  defp traverse({:with, _meta, args} = ast, {issues, issue_meta}) do
    new_issues =
      args
      |> Enum.filter(&tagged_with_clause?/1)
      |> Enum.map(fn {:<-, clause_meta, _args} ->
        format_issue(issue_meta,
          message:
            "Do not use tagged-tuple workarounds in `with` clauses. " <>
              "Use `case` when the error source matters, or normalise errors in helper functions.",
          line_no: clause_meta[:line],
          trigger: "<-"
        )
      end)

    {ast, {new_issues ++ issues, issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}

  # Detects patterns like `{:tag, {:ok, _}} <- {:tag, expr}` or
  # `{:tag, {:error, _}} <- {:tag, expr}` where the same atom appears on both sides.
  defp tagged_with_clause?({:<-, _meta, [{tag_left, {result, _value}}, {tag_right, _expr}]})
       when is_atom(tag_left) and tag_left == tag_right and result in [:ok, :error],
       do: true

  defp tagged_with_clause?(_clause), do: false
end
