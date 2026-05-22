defmodule LexCredo do
  @moduledoc """
  LexCredo provides custom Credo checks for Elixir projects, targeting
  anti-patterns that are commonly introduced by both AI coding agents and
  human developers.

  The checks are drawn primarily from:

  - [Elixir's official anti-patterns guide](https://hexdocs.pm/elixir/what-anti-patterns.html)
  - [Chris Keathley's "Good and Bad Elixir"](https://keathley.io/blog/good-and-bad-elixir.html)

  ## Usage

  Add `lex_credo` to your dependencies:

      def deps do
        [
          {:lex_credo, "~> #{Mix.Project.config()[:version]}", only: [:dev, :test], runtime: false}
        ]
      end

  Then enable checks in your `.credo.exs`:

      %{
        configs: [
          %{
            name: "default",
            checks: %{
              enabled: [
                {LexCredo.Check.Design.NoNestedModules, []},
                {LexCredo.Check.Readability.DocExamplesSection, []},
                {LexCredo.Check.Refactor.NoEnumWrapperFunctions, []},
                {LexCredo.Check.Warning.NoComplexWithElse, []},
                {LexCredo.Check.Warning.NoEnumAllAssert, []},
                {LexCredo.Check.Warning.NoPipeIntoCase, []},
                {LexCredo.Check.Warning.NoProcessSleepInTests, []},
                {LexCredo.Check.Warning.NoTaggedWithClauses, []},
                {LexCredo.Check.Warning.PreferBooleanOperators, []},
                {LexCredo.Check.Warning.UsePositiveTypeGuards, []},
                {LexCredo.Check.Warning.UseStartSupervised, []}
              ]
            ]
          }
        ]
      }

  > #### Opinionated checks {: .warning}
  >
  > Several checks in this library are deliberately opinionated and may produce
  > false positives or conflict with your team's conventions. They are here to
  > **assist**, not to legislate. Suppress individual warnings with
  > [`# credo:disable-for-next-line`](https://hexdocs.pm/credo/config_comments.html)
  > or disable a check entirely by moving it to the `disabled:` list in
  > `.credo.exs`.

  ## General Parameters

  All checks support the standard Credo parameters:

  - **`false`** — disable the check entirely:

        {LexCredo.Check.Warning.NoPipeIntoCase, false}

  - **`exit_status`** — make a check advisory-only (reports issues but does not
    fail the build):

        {LexCredo.Check.Warning.PreferBooleanOperators, exit_status: 0}

  - **`priority`** — override the check's base priority.

  - **`exclude_test_files`** — skip test files for this check. Defaults to
    `true` for `NoNestedModules` and `false` for everything else:

        {LexCredo.Check.Readability.DocExamplesSection, exclude_test_files: true}

  ## Available Checks

  ### Design

  - `LexCredo.Check.Design.NoNestedModules` — flags `defmodule` nested inside
    another `defmodule`. Each module should live in its own file.

  ### Readability

  - `LexCredo.Check.Readability.DocExamplesSection` (controversial) — flags `@doc` strings
    on public functions that are missing a `## Examples` section.

  ### Refactor

  - `LexCredo.Check.Refactor.NoEnumWrapperFunctions` (controversial) — flags named functions
    whose entire body is a single `Enum.*` or `Stream.*` transformation call.

  ### Warning

  - `LexCredo.Check.Warning.NoComplexWithElse` — flags `with` expressions whose
    `else` block exceeds `max_else_clauses` (default: `1`).

  - `LexCredo.Check.Warning.NoEnumAllAssert` *(test files only)* — flags
    `assert Enum.all?/2` in tests; prefer a `for` loop with individual assertions
    that report the failing element.

  - `LexCredo.Check.Warning.NoPipeIntoCase` (controversial) — flags `|> case do` patterns;
    bind the value to a variable first.

  - `LexCredo.Check.Warning.NoProcessSleepInTests` *(test files only)* — flags
    `Process.sleep/1` and `Process.alive?/1` in tests; use `Process.monitor/1`
    and `assert_receive` instead.

  - `LexCredo.Check.Warning.NoTaggedWithClauses` — flags tagged-tuple
    workarounds in `with` clauses (e.g. `{:tag, {:ok, _}} <- {:tag, expr}`).

  - `LexCredo.Check.Warning.PreferBooleanOperators` (controversial) — flags `&&`, `||`, `!`
    when at least one operand is clearly boolean-returning; prefer `and`, `or`,
    `not`.

  - `LexCredo.Check.Warning.UsePositiveTypeGuards` — flags negated type guards
    in function heads (e.g. `when not is_nil(x)`, `when x != nil`); use a
    precise positive guard instead.

  - `LexCredo.Check.Warning.UseStartSupervised` *(test files only)* — flags
    direct `GenServer.start_link/2` and similar calls in tests; use
    `start_supervised!/1` for automatic cleanup.

  > #### Controversial checks {: .tip}
  >
  > Checks marked *(controversial)* reflect opinions that are actively debated in the Elixir
  > community. They are enabled by default because they catch real problems for
  > AI-generated code, but your team may reasonably disagree. Review and disable
  > as needed.
  """

  @version Mix.Project.config()[:version]

  @doc """
  Returns the current version of LexCredo.

  ## Examples

      iex> LexCredo.version()
      "#{Mix.Project.config()[:version]}"

  """
  @spec version() :: String.t()
  def version, do: @version
end
