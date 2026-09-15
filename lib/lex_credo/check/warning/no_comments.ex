defmodule LexCredo.Check.Warning.NoComments do
  use Credo.Check,
    category: :warning,
    base_priority: :high,
    param_defaults: [
      exclude_test_files: false,
      paths: [~r{(?:^|/)priv/[^/]+/migrations(?:/|$)}]
    ],
    explanations: [
      check: """
      Do not add comments or documentation attributes to files targeted by this check.

      By default, it targets Ecto migration files, which should be concise,
      executable records of schema and data changes. Configure `paths` to enforce
      the same policy in other directories or files. Document the rationale for a
      migration, field type, or operational constraint in the pull request, issue,
      ADR, or deployment documentation instead.

      For an exceptional targeted file, disable this check for that file with:

          # credo:disable-for-this-file LexCredo.Check.Warning.NoComments
      """,
      params: [
        exclude_test_files:
          "When `true`, skips test files. Default: `false`. This normally has no effect because " <>
            "Ecto migrations are not test files.",
        paths:
          "Files to inspect. Each entry may be an exact relative file path, a relative directory " <>
            "path, or a regular expression. Defaults to conventional Ecto migration directories " <>
            "(`priv/*/migrations/`)."
      ]
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @documentation_attributes [:moduledoc, :doc, :typedoc, :shortdoc]
  @disable_directive "credo:disable-for-this-file #{inspect(__MODULE__)}"

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if targeted_file?(source_file, params) and
         not disabled_for_file?(source_file) and
         not CheckHelpers.skip_for_test_file?(source_file, params, __MODULE__) do
      issue_meta = IssueMeta.for(source_file, params)

      (hash_comment_issues(source_file, issue_meta) ++
         documentation_issues(source_file, issue_meta))
      |> Enum.sort_by(& &1.line_no)
    else
      []
    end
  end

  defp targeted_file?(%SourceFile{filename: filename}, params) do
    params
    |> Params.get(:paths, __MODULE__)
    |> Enum.any?(&path_matches?(filename, &1))
  end

  defp path_matches?(filename, %Regex{} = path), do: String.match?(filename, path)

  defp path_matches?(filename, path) when is_binary(path) do
    path = String.trim_trailing(path, "/")
    filename == path or String.starts_with?(filename, path <> "/")
  end

  defp disabled_for_file?(source_file) do
    source_file
    |> SourceFile.source()
    |> String.contains?(@disable_directive)
  end

  defp hash_comment_issues(source_file, issue_meta) do
    case Code.string_to_quoted_with_comments(SourceFile.source(source_file), columns: true) do
      {:ok, _ast, comments} ->
        Enum.map(comments, fn %{line: line, text: text} ->
          format_issue(issue_meta,
            message:
              "Comments do not belong in migration files. Document the rationale outside the migration.",
            line_no: line,
            trigger: text
          )
        end)

      {:error, _error} ->
        []
    end
  end

  defp documentation_issues(source_file, issue_meta) do
    Credo.Code.prewalk(source_file, &traverse/2, {[], issue_meta})
    |> elem(0)
  end

  defp traverse(
         {:@, meta, [{attribute, _attribute_meta, _arguments}]} = ast,
         {issues, issue_meta}
       )
       when attribute in @documentation_attributes do
    issue =
      format_issue(issue_meta,
        message:
          "Documentation attributes do not belong in migration files. Document the rationale outside the migration.",
        line_no: meta[:line],
        trigger: "@#{attribute}"
      )

    {ast, {[issue | issues], issue_meta}}
  end

  defp traverse(ast, acc), do: {ast, acc}
end
