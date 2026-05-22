defmodule LexCredo.Check.Warning.NoTaggedWithClauses do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    explanations: [
      check: """
      Do not use tagged-tuple workarounds in `with` clauses to identify which
      clause failed in the `else` block.

      If you need to distinguish between different failure sources, use `case`
      instead. If you do not need to distinguish, normalise error return types
      in small private helper functions.

          # BAD — tagging each clause so the else block can identify the source
          with {:service, {:ok, resp}} <- {:service, call_service(data)},
               {:decode, {:ok, decoded}} <- {:decode, Jason.decode(resp)} do
            :ok
          else
            {:service, {:error, e}} -> handle_service_error(e)
            {:decode, {:error, e}} -> handle_decode_error(e)
          end

          # GOOD — normalise errors in helpers and let with focus on the happy path
          with {:ok, resp} <- call_service(data),
               {:ok, decoded} <- decode(resp) do
            :ok
          end

          defp decode(resp) do
            case Jason.decode(resp) do
              {:ok, _} = ok -> ok
              {:error, reason} -> {:error, {:decode, reason}}
            end
          end
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
