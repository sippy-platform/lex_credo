# LexCredo

[![Last Commit](https://img.shields.io/github/last-commit/sippy-platform/lex_credo)](https://github.com/sippy-platform/lex_credo)
[![Hex Version](https://img.shields.io/hexpm/v/lex_credo)](https://hex.pm/packages/lex_credo)
[![Hex Downloads](https://img.shields.io/hexpm/dt/lex_credo)](https://hex.pm/packages/lex_credo)
[![Documentation](https://img.shields.io/badge/hex-docs-purple?logo=elixir)](https://hexdocs.pm/lex_credo)
[![Coverage](https://codecov.io/gh/sippy-platform/lex_credo/graph/badge.svg)](https://codecov.io/gh/sippy-platform/lex_credo)

A collection of custom [Credo](https://github.com/rrrene/credo) checks for Elixir projects, designed to catch common anti-patterns and guide both **human developers and AI coding agents** toward idiomatic, maintainable Elixir code.

> **Note:** This library was originally created to assist AI agents (such as Copilot, Claude, and similar tools) in avoiding common Elixir anti-patterns that they tend to reproduce. The checks are equally useful for human developers, but the primary motivation was to give AI-assisted codebases a static analysis layer that pushes back on known-bad patterns before they land in review.

Anti-patterns targeted by this library are drawn primarily from:

- [Elixir's official anti-patterns guide](https://hexdocs.pm/elixir/what-anti-patterns.html)
- [Chris Keathley's "Good and Bad Elixir"](https://keathley.io/blog/good-and-bad-elixir.html)

> #### Note {: .tip}
>
> Checks are here to assist, not to legislate. Some rules in this library are genuinely controversial within the Elixir community — reasonable people disagree. The goal is to nudge toward good defaults, not to enforce a single style religion. If a check doesn't fit your project's conventions, disable it. See [Disabling Checks](#disabling-checks).

---

## Installation

Add `lex_credo` to your dependencies in `mix.exs`. It is typically only needed in `:dev` and `:test`:

```elixir
def deps do
  [
    {:lex_credo, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

Then run:

```sh
mix deps.get
```

---

## Usage

### 1. Add checks to your `.credo.exs`

In the `checks: %{enabled: [...]}` section of your `.credo.exs`, add any checks you want to enable:

```elixir
checks: %{
  enabled: [
    # ... your existing checks ...

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
    {LexCredo.Check.Warning.UseStartSupervised, []},
  ]
}
```

### 2. Run Credo

```sh
mix credo
# or for strict mode (includes low-priority checks):
mix credo --strict
```

---

## General Parameters

All checks accept the following parameters.

### `exclude_test_files`

Skip test files for this check. Default is `true` for `NoNestedModules` (which
skips test files by default to allow inline helper modules) and `false` for all
other checks.

```elixir
# Skip test files for a check that normally runs everywhere
{LexCredo.Check.Readability.DocExamplesSection, [exclude_test_files: true]}

# Run NoNestedModules in test files too
{LexCredo.Check.Design.NoNestedModules, [exclude_test_files: false]}
```

### Standard Credo parameters

- **`false`** — disable the check entirely:

  ```elixir
  {LexCredo.Check.Warning.NoPipeIntoCase, false}
  ```

- **`exit_status`** — make a check advisory-only (reports issues but does not
  affect the exit code):

  ```elixir
  {LexCredo.Check.Warning.PreferBooleanOperators, [exit_status: 0]}
  ```

- **`priority`** — override the check's base priority.

> #### Suppressing individual warnings {: .tip}
>
> Use a Credo inline comment to suppress a single occurrence without disabling
> the check globally:
>
>     result |> case do  # credo:disable-for-next-line LexCredo.Check.Warning.NoPipeIntoCase

---

## Included Checks

### Design

#### `LexCredo.Check.Design.NoNestedModules`

**Category:** Design | **Priority:** High

Flags `defmodule` blocks nested inside another `defmodule`. Nested modules obscure the module hierarchy and make code harder to navigate. Define each module in its own file instead.

```elixir
# flagged
defmodule Outer do
  defmodule Inner do  # <-- flagged
    ...
  end
end

# preferred
defmodule Outer do ... end
defmodule Outer.Inner do ... end
```

> Skips test files, where anonymous and helper modules inline are common.

---

### Readability

#### `LexCredo.Check.Readability.DocExamplesSection`

**Category:** Readability | **Priority:** Normal

> #### Controversial {: .warning}
>
> Requiring an `## Examples` section in every public function doc is a strong convention that not all teams share. Some functions are genuinely self-documenting. Consider disabling this check if your team finds it too prescriptive.

Flags `@doc` strings on public functions that are missing an `## Examples` section. Inline examples improve discoverability and double as living documentation when used with `doctest`.

```elixir
# flagged — no Examples section
@doc """
Parses a date string.
"""
def parse_date(str), do: ...

# preferred
@doc """
Parses a date string.

## Examples

    iex> MyApp.parse_date("2024-01-01")
    {:ok, ~D[2024-01-01]}
"""
def parse_date(str), do: ...
```

> Does not fire on `@doc false` or `@doc nil`.

---

### Refactor

#### `LexCredo.Check.Refactor.NoEnumWrapperFunctions`

**Category:** Refactor | **Priority:** Normal

> #### Controversial {: .warning}
>
> There are legitimate reasons to wrap an `Enum` call in a named function (naming intent, easier testing, future extensibility). This check flags only the cases where the wrapper adds no abstraction value at all. If your wrapper function carries a meaningful name that clarifies intent, disable this check or add it to an allow-list.

Flags named functions (`def`/`defp`) whose entire body is a single `Enum` or `Stream` transformation call (`map`, `flat_map`, `each`, `map_reduce`, `flat_map_reduce`, `scan`). These wrappers add indirection without adding meaning — callers can compose `Enum` directly.

```elixir
# flagged
def user_names(users), do: Enum.map(users, & &1.name)

# preferred — inline at the call site
Enum.map(users, & &1.name)
# or, if transformation logic is complex, name the transform itself
def name_of(%User{name: name}), do: name
Enum.map(users, &name_of/1)
```

> Aggregation and predicate functions (`any?`, `all?`, `count`, `sum`, etc.) are intentionally excluded from this check.

---

### Warning

#### `LexCredo.Check.Warning.NoComplexWithElse`

**Category:** Warning | **Priority:** Normal | **Configurable**

Flags `with` expressions whose `else` block has more than `max_else_clauses` clauses (default: `1`). Complex `else` blocks usually signal that error normalisation should happen in a helper or that a `case` expression is more appropriate.

```elixir
# flagged — 2 else clauses, default max is 1
with {:ok, user} <- fetch_user(id),
     {:ok, post} <- fetch_post(user) do
  post
else
  {:error, :not_found} -> {:error, :user_not_found}
  {:error, :forbidden} -> {:error, :access_denied}
end

# preferred — each function returns a normalised error atom,
# so a single catch-all clause in else is sufficient
with {:ok, user} <- fetch_user(id),
     {:ok, post} <- fetch_post(user) do
  post
else
  {:error, reason} -> {:error, reason}
end
```

**Configuration:**

```elixir
{LexCredo.Check.Warning.NoComplexWithElse, [max_else_clauses: 2]}
```

---

#### `LexCredo.Check.Warning.NoEnumAllAssert`

**Category:** Warning | **Priority:** Normal | **Test files only**

Flags `assert Enum.all?(collection, predicate)` in test files. When this assertion fails, you get no indication of *which* element failed. A `for` loop with individual assertions gives a specific failure message for each item.

```elixir
# flagged
assert Enum.all?(users, &(&1.active))

# preferred
for user <- users do
  assert user.active, "expected user #{user.id} to be active"
end
```

---

#### `LexCredo.Check.Warning.NoPipeIntoCase`

**Category:** Warning | **Priority:** High

> #### Controversial {: .warning}
>
> The `|> case do` pattern is used widely in the Elixir community and is syntactically valid. Many developers find it natural and prefer it for readability in pipelines. This check reflects the preference from [Keathley's style guide](https://keathley.io/blog/good-and-bad-elixir.html) to bind the intermediate value first so it can be inspected more easily. Disable if your team is comfortable with `|> case do`.

Flags `|> case do` patterns. Binding the piped value to a named variable before branching makes the code easier to debug and the variable available for logging or pattern matching.

```elixir
# flagged
result
|> transform()
|> case do
  {:ok, val} -> val
  {:error, _} -> nil
end

# preferred
transformed = result |> transform()

case transformed do
  {:ok, val} -> val
  {:error, _} -> nil
end
```

---

#### `LexCredo.Check.Warning.NoProcessSleepInTests`

**Category:** Warning | **Priority:** High | **Test files only**

Flags `Process.sleep/1` and `Process.alive?/1` in test files. `sleep` makes test suites slow and flaky; `alive?` produces race conditions. Use `Process.monitor/1` + `assert_receive {:DOWN, ...}` or `:sys.get_state/1` for deterministic synchronisation.

```elixir
# flagged
Process.sleep(100)
assert Process.alive?(pid)

# preferred
ref = Process.monitor(pid)
assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
```

---

#### `LexCredo.Check.Warning.NoTaggedWithClauses`

**Category:** Warning | **Priority:** High

Flags the tagged-tuple workaround used to identify which `with` clause failed in the `else` block:

```elixir
# flagged — tags exist only to tell apart which step failed
with {:user, {:ok, user}} <- {:user, fetch_user(id)},
     {:post, {:ok, post}} <- {:post, fetch_post(user)} do
  {:ok, post}
else
  {:user, {:error, reason}} -> {:error, {:user, reason}}
  {:post, {:error, reason}} -> {:error, {:post, reason}}
end

# preferred — each function returns a distinct error atom,
# so the step that failed is clear without wrapping tuples
with {:ok, user} <- fetch_user(id),
     {:ok, post} <- fetch_post(user) do
  {:ok, post}
else
  {:error, :user_not_found} = err -> err
  {:error, :post_not_found} = err -> err
end
```

This pattern exists to work around `with`'s inability to match partial results in `else`. Prefer having each function return a distinct, self-describing error tuple so no wrapping is needed.

---

#### `LexCredo.Check.Warning.PreferBooleanOperators`

**Category:** Warning | **Priority:** Normal

> #### Controversial {: .warning}
>
> The `&&`/`||`/`!` vs `and`/`or`/`not` distinction is one of the most debated style points in Elixir. Both sets of operators are valid in non-guard contexts. `&&`/`||` are more familiar to developers coming from other languages. This check reflects the opinion from the official anti-patterns guide that `and`/`or`/`not` should be preferred when operands are boolean-typed, since it signals intent more clearly. Disable if your team prefers `&&`/`||` uniformly.

Flags `&&`, `||`, and `!` when at least one operand is a clearly boolean-yielding expression (an `is_*` guard, a comparison, a boolean literal, or another boolean operator). In these cases, `and`, `or`, and `not` are preferred.

```elixir
# flagged — operands are boolean-typed
is_binary(x) && is_integer(y)
has_permission?(user) || is_admin?(user)
!is_nil(value)

# preferred
is_binary(x) and is_integer(y)
has_permission?(user) or is_admin?(user)
not is_nil(value)

# not flagged — truthy/falsy short-circuit idiom, not boolean-typed
user && user.name
config[:timeout] || 5_000
```

---

#### `LexCredo.Check.Warning.UsePositiveTypeGuards`

**Category:** Warning | **Priority:** High

Flags negated type guards in function heads. A negated guard like `not is_nil(x)` does not tell you what `x` *is* — only what it isn't. Prefer a specific positive guard (`is_binary`, `is_integer`, etc.) that accurately constrains the clause.

```elixir
# flagged
def process(x) when not is_nil(x), do: ...
def process(x) when x != nil, do: ...

# preferred
def process(x) when is_binary(x), do: ...
```

Covers `not is_*()`, `!= nil`, and `!== nil` patterns. Recurses through compound `and`/`or` guards so all violations in a single guard are reported.

---

#### `LexCredo.Check.Warning.UseStartSupervised`

**Category:** Warning | **Priority:** Normal | **Test files only**

Flags direct `start_link`/`start` calls to `GenServer`, `Agent`, `Task`, `Supervisor`, and `DynamicSupervisor` in test files. Processes started this way are not automatically cleaned up when the test exits, which can cause interference between tests. Use `start_supervised!/1` (or `start_supervised/1`) instead.

```elixir
# flagged
{:ok, pid} = GenServer.start_link(MyServer, [])

# preferred
pid = start_supervised!(MyServer)
```

---

## Disabling Checks

To disable a check project-wide, move it to the `disabled:` list in `.credo.exs`:

```elixir
checks: %{
  disabled: [
    {LexCredo.Check.Warning.NoPipeIntoCase, []},
  ]
}
```

See [General Parameters](#general-parameters) for per-occurrence suppression and
the [Credo inline config documentation](https://hexdocs.pm/credo/inline_config.html)
for all available directives.

---

## Contributing

New checks should follow the same structure as the existing ones: one module per file under `lib/lex_credo/check/<category>/`, using `use Credo.Check` and returning a list of issues from `run/2`. Run `mix precommit` before opening a pull request — it compiles, formats, runs Credo (including these checks on themselves), and runs the test suite.

```sh
mix precommit
```

---

## License

MIT
