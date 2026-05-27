defmodule LexCredo do
  @moduledoc """
  LexCredo provides custom Credo checks for Elixir projects, targeting
  anti-patterns that are commonly introduced by both AI coding agents and
  human developers.

  The checks are drawn primarily from:

  - [Elixir's official anti-patterns guide](https://hexdocs.pm/elixir/what-anti-patterns.html)
  - [Chris Keathley's "Good and Bad Elixir"](https://keathley.io/blog/good-and-bad-elixir.html)

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

  - `LexCredo.Check.Warning.StructMatchInFunctionHead` — flags `%Struct{} = param`
    at the top level of a function body when `param` is a plain-variable
    argument; moving the struct match to the function head makes the type
    visible in the signature and enables type inference.

  - `LexCredo.Check.Warning.NoComplexWithElse` — flags `with` expressions whose
    `else` block exceeds `max_else_clauses` (default: `1`).

  - `LexCredo.Check.Warning.NoEnumAllAssert` *(test files only)* — flags
    `assert Enum.all?/2` in tests; prefer a `for` loop with individual assertions
    that report the failing element.

  - `LexCredo.Check.Warning.NoProcessSleepInTests` *(test files only)* — flags
    `Process.sleep/1` and `Process.alive?/1` in tests; use `Process.monitor/1`
    and `assert_receive` instead.

  - `LexCredo.Check.Warning.NonBooleanWithStrictOperator` — flags `and`/`or`/`not`
    when an operand is clearly non-boolean (struct field access without `?` suffix,
    non-boolean literal, etc.); suggests `&&`/`||`/`!` to avoid a runtime
    `ArgumentError` and to signal truthy/falsy intent.

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
