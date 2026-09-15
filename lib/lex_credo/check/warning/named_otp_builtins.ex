defmodule LexCredo.Check.Warning.NamedOtpBuiltins do
  use Credo.Check,
    category: :warning,
    base_priority: :normal,
    param_defaults: [exclude_test_files: false],
    explanations: [
      check: """
      Give `DynamicSupervisor` and `Registry` child specs a `name:` option.

      A name lets callers interact with the process through the standard APIs
      without passing its PID around. This check only examines literal child
      specs, so dynamically constructed options are left alone.

          # BAD
          {DynamicSupervisor, strategy: :one_for_one}
          {Registry, keys: :unique}

          # GOOD
          {DynamicSupervisor, strategy: :one_for_one, name: MyApp.DynamicSupervisor}
          {Registry, keys: :unique, name: MyApp.Registry}
      """,
      params: [
        exclude_test_files: "When `true`, skips test files. Default: `false`."
      ]
    ]

  alias Credo.IssueMeta
  alias LexCredo.CheckHelpers

  @named_otp_builtins [DynamicSupervisor, Registry]

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

  defp traverse({module_ast, options} = ast, {issues, issue_meta}) when is_list(options) do
    case module_name(module_ast) do
      named_module when named_module in @named_otp_builtins ->
        if Keyword.has_key?(options, :name) do
          {ast, {issues, issue_meta}}
        else
          issue =
            format_issue(issue_meta,
              message:
                "Give the #{inspect(named_module)} child spec a `name:` option so it can be addressed by name.",
              line_no: node_line(module_ast),
              trigger: inspect(named_module)
            )

          {ast, {[issue | issues], issue_meta}}
        end

      _module ->
        {ast, {issues, issue_meta}}
    end
  end

  defp traverse(ast, acc), do: {ast, acc}

  defp module_name({:__aliases__, _meta, aliases}) do
    module = Module.concat(aliases)
    if module in @named_otp_builtins, do: module
  end

  defp module_name(_module), do: nil

  defp node_line({:__aliases__, meta, _aliases}), do: meta[:line]
end
