# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Removed

- `LexCredo.Check.Warning.NoPipeIntoCase` — superseded by the built-in
  `Credo.Check.Readability.BlockPipe`, which covers `|>` into any block
  expression, not just `case`. Enable `BlockPipe` in `.credo.exs` instead.
- `LexCredo.Check.Warning.NoTaggedWithClauses` — superseded by the built-in
  `Credo.Check.Readability.WithCustomTaggedTuple`, which is broader (catches
  any same-tag pattern, not only `:ok`/`:error` wrappers). Enable
  `WithCustomTaggedTuple` in `.credo.exs` instead.

### Added

- `LexCredo.Check.Warning.NonBooleanWithStrictOperator` — flags `and`/`or`/`not`
  when any operand is clearly non-boolean (struct field access without `?` suffix,
  non-boolean literal, `nil`, etc.); suggests `&&`/`||`/`!` to avoid a runtime
  `ArgumentError` or misleading truthy/falsy semantics. Complements
  `PreferBooleanOperators`.
- `LexCredo.Check.Warning.StructMatchInFunctionHead` — flags `%Struct{} = param`
  at the top level of a function body when `param` is a plain-variable argument.
  Moving the struct match to the function head makes the type visible in the
  signature and enables Elixir's type checker to infer the parameter type.
  Only top-level body statements are checked; matches nested inside `case`,
  `if`, `with`, etc. are left alone.
- `LexCredo.Check.Warning.PreferIsNil` — flags `== nil`, `!= nil`, `=== nil`,
  and `!== nil` comparisons (both operand orders); suggests `is_nil(x)` and
  `not is_nil(x)` for consistency with the `is_*` guard family. Note: conflicts
  with the built-in `Credo.Check.Refactor.NegatedIsNil`; disable one.

## [0.1.0] - 2026-05-22

Initial release.

### Added

**Checks – Design**

- `LexCredo.Check.Design.NoNestedModules` — flags module definitions nested
  inside another module; skips test files by default
  (`exclude_test_files: true`).

**Checks – Readability**

- `LexCredo.Check.Readability.DocExamplesSection` — flags public functions
  whose `@doc` string contains code blocks but no `## Examples` heading.

**Checks – Refactor**

- `LexCredo.Check.Refactor.NoEnumWrapperFunctions` — flags single-function
  bodies that do nothing but delegate to `Enum`/`Stream` (`map`, `flat_map`,
  `each`, `map_reduce`, `flat_map_reduce`, `scan`).

**Checks – Warning**

- `LexCredo.Check.Warning.NoComplexWithElse` — flags `with` expressions whose
  `else` block exceeds `max_else_clauses` (default: `1`).
- `LexCredo.Check.Warning.NoEnumAllAssert` — flags `assert Enum.all?/2` in
  test files; suggests per-element assertions for clearer failure messages.
- `LexCredo.Check.Warning.NoPipeIntoCase` — flags `|> case do` patterns;
  suggests binding the intermediate value to a named variable first.
- `LexCredo.Check.Warning.NoProcessSleepInTests` — flags `Process.sleep/1`
  and `Process.alive?/1` in test files; suggests `Process.monitor/1` +
  `assert_receive` for deterministic synchronisation.
- `LexCredo.Check.Warning.NoTaggedWithClauses` — flags the
  `{:tag, {:ok, _}} <- {:tag, expr}` workaround used to identify which `with`
  clause failed in the `else` block.
- `LexCredo.Check.Warning.PreferBooleanOperators` — flags `&&`, `||`, and `!`
  when at least one operand is a boolean-typed expression; suggests `and`,
  `or`, and `not`. Does not flag truthy/falsy short-circuit patterns such as
  `user && user.name`.
- `LexCredo.Check.Warning.UsePositiveTypeGuards` — flags negated type guards
  in function heads (`not is_nil(x)`, `x != nil`, etc.); suggests a specific
  positive guard that accurately constrains the clause.
- `LexCredo.Check.Warning.UseStartSupervised` — flags direct `start_link`/
  `start` calls to `GenServer`, `Agent`, `Task`, `Supervisor`, and
  `DynamicSupervisor` in test files; suggests `start_supervised!/1`.

**General**

- `exclude_test_files` boolean parameter on all checks — set to `true` to
  skip files under `test/`; defaults to `true` for `NoNestedModules`, `false`
  for all others.
- GitHub Actions CI workflow: format check → compile (warnings-as-errors) →
  `credo --strict` → ExCoveralls; reads Elixir/OTP versions from
  `.tool-versions`.
- ExCoveralls configured with an 80 % minimum line-coverage threshold.
- ExDoc configured with `main: "readme"`, check modules grouped by category,
  and README / CHANGELOG / LICENSE included as extras.
- MIT license.

### Fixed

- `PreferBooleanOperators`: `boolean_like?/1` is now recursive for `&&`/`||`
  — they are only considered boolean-like when their own operands are
  boolean-like. This eliminates false positives on truthy/falsy short-circuit
  idioms such as `(user && user.name) || "default"`.
- `UsePositiveTypeGuards`: extended pattern matching to cover `not is_*(x)`
  for all standard type-guard functions, not just `is_nil`.
