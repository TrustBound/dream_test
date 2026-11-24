# Coding Standards

This document defines the coding conventions for Dream Test. These are **project-specific rules**, not general Gleam guidelines—they may be stricter than typical Gleam style.

**Goals**: clarity, explicitness, debuggability.

---

## Quick Reference

| Rule                                                                | Summary                                          |
| ------------------------------------------------------------------- | ------------------------------------------------ |
| [No nested `case`](#1-no-nested-case-expressions)                   | One `case` per function; extract helpers         |
| [No closures](#2-no-closures)                                       | Only to start a process or store a callback      |
| [No anonymous functions](#3-no-anonymous-functions-in-library-code) | Every function gets a name                       |
| [No abbreviations](#4-no-abbreviated-identifiers)                   | `context` not `ctx`, `failure` not `f`           |
| [Reserved words](#5-directory-and-module-naming)                    | Don't use `assert` in paths                      |
| [Pipes over builders](#6-pipes-over-fluent-builders)                | Return values, not functions                     |
| [Import style](#7-import-style)                                     | Unqualified preferred; alias conflicting modules |
| [Config records](#8-config-records-for-multi-parameter-functions)   | Named fields over long parameter lists           |

---

## 1. No Nested `case` Expressions

**Rule**: Do not nest `case` expressions. Extract inner logic into named helper functions.

**Why**: Nested pattern matches are hard to read, test, and debug. Named helpers make control flow explicit and improve stack traces.

#### ❌ Don't: a nested `case` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/nested_case_dont.gleam#L10-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle(value1, value2) {
  case value1 {
    Some(x) ->
      case value2 {
        Ok(y) -> do_something(x, y)
        Error(e) -> handle_error(e)
      }
    None -> handle_none()
  }
}
```

#### ✅ Do: a named helper <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/nested_case_do.gleam#L9-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle(value1, value2) {
  case value1 {
    Some(x) -> handle_with_value(x, value2)
    None -> handle_none()
  }
}

fn handle_with_value(x, value2) {
  case value2 {
    Ok(y) -> do_something(x, y)
    Error(e) -> handle_error(e)
  }
}
```

---

## 2. No Closures

**Rule**: Do not use closures (functions capturing outer scope variables) in library code. Define all functions at the module level with explicit parameters.

**Why**: Closures hide dependencies. Explicit parameters make data flow obvious and simplify testing.

#### ❌ Don't: a closure <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/closure_dont.gleam#L7-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn make_checker(limit) {
  fn(value) { value < limit }
}
```

#### ✅ Do: an explicit parameter <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/closure_do.gleam#L6-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn is_less_than(limit, value) {
  value < limit
}
```

If you need configurable behavior, use a data type or explicit parameter—not a closure.

If a function runs another function later, for example in a sandbox, give it the function and its input as two parameters. Then the caller passes a named function and its data, and needs no closure. `sandbox.run_isolated(config, run, input)` works this way.

### The two allowed closures

Library code may use a closure only in these two cases:

1. **Process start.** The function given to `spawn` or `spawn_unlinked` can capture the values the new process needs.
2. **Stored callbacks.** A function that the framework stores and calls later, such as a Gherkin scenario body in a `Node`, can capture the data that a named function needs.

In both cases, the closure body is exactly one call to a named top-level function, as in `fn() { execute_scenario(scenario_id, steps, registry) }`. All logic is in a named function.

Do not write a closure only to change the shape of a user function. A hook or a test body keeps the shape that the user wrote: `unit.before_all(setup)` stores `BeforeAll(NoInput(setup))`, and the runner calls it with `types.call`. If two function types do not match, change the stored type, not the function.

**Why**: A new BEAM process gets its start data only through the function it runs. A stored callback must have the one shape of its record field, and a callback that needs captured data has no other way to get it. No named function can do these two jobs. A body that is one named call keeps the logic named, searchable and visible in stack traces, and the closure only moves data.

#### ❌ Don't: logic in the closure <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/process_start_dont.gleam#L12-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn start_worker(
  result_subject: Subject(WorkerMessage(a)),
  run: fn(input) -> a,
  input: input,
  show_crash_reports: Bool,
) -> Pid {
  spawn_unlinked(fn() {
    case show_crash_reports {
      True -> send(result_subject, TestCompleted(run(input)))
      False -> send(result_subject, caught_message(run_catching(run, input)))
    }
  })
}
```

#### ✅ Do: one named call in the closure <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/process_start_do.gleam#L11-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn start_worker(
  result_subject: Subject(WorkerMessage(a)),
  run: fn(input) -> a,
  input: input,
  show_crash_reports: Bool,
) -> Pid {
  spawn_unlinked(fn() {
    run_worker(result_subject, run, input, show_crash_reports)
  })
}

fn run_worker(
  result_subject: Subject(WorkerMessage(a)),
  run: fn(input) -> a,
  input: input,
  show_crash_reports: Bool,
) -> Nil {
  case show_crash_reports {
    True -> send(result_subject, TestCompleted(run(input)))
    False -> send(result_subject, caught_message(run_catching(run, input)))
  }
}
```

Erlang FFI follows the same rule: use a list comprehension or `fun name/arity`, not `fun(X) -> ... end`.

---

## 3. No Anonymous Functions in Library Code

**Rule**: Every function must have a name and be defined at the top level. No inline `fn(...) { ... }` in library modules.

**Why**: Named functions appear in stack traces, are searchable, and encourage reuse. Anonymous functions encourage "inline cleverness."

#### ❌ Don't: an anonymous test body <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/anonymous_test_dont.gleam#L9-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn math_tests() -> TestSuite {
  describe("math", [
    it("adds numbers", fn() {
      1 + 2
      |> should
      |> be_equal(3)
      |> or_fail_with("1 + 2 should be 3")
    }),
  ])
}
```

#### ✅ Do: a named test function <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/anonymous_test_do.gleam#L9-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn math_tests() -> TestSuite {
  describe("math", [
    it("adds numbers", adds_numbers_test),
  ])
}

fn adds_numbers_test() -> Result(AssertionResult, String) {
  1 + 2
  |> should
  |> be_equal(3)
  |> or_fail_with("1 + 2 should be 3")
}
```

**Exception**: Test files may use anonymous functions for simple inline test bodies (as shown in the README examples). Library code (under `src/`) must not, except for the [two allowed closures](#the-two-allowed-closures).

---

## 4. No Abbreviated Identifiers

**Rule**: Use full, descriptive names for important identifiers.

**Why**: Descriptive names reduce cognitive load. They help future readers understand code without jumping around.

| ❌ Don't | ✅ Do     |
| -------- | --------- |
| `ctx`    | `context` |
| `res`    | `result`  |
| `f`      | `failure` |
| `cfg`    | `config`  |
| `msg`    | `message` |
| `val`    | `value`   |

#### ❌ Don't: an abbreviated name <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/abbreviation_dont.gleam#L8-L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn status_from_failures(fs: List(AssertionFailure)) -> Status {
  case fs {
    [] -> Passed
    _ -> Failed
  }
}
```

#### ✅ Do: a full name <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/abbreviation_do.gleam#L7-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn status_from_failures(
  failures failures: List(AssertionFailure),
) -> Status {
  case failures {
    [] -> Passed
    _ -> Failed
  }
}
```

---

## 5. Directory and Module Naming

**Rule**: Do not use reserved words in directory or module names.

**Why**: Reserved words cause confusing syntax errors.

| ❌ Avoid            | ✅ Use instead          |
| ------------------- | ----------------------- |
| `dream_test/assert` | `dream_test/matchers`   |
| `dream_test/type`   | `dream_test/types`      |

**Module path conventions**:

- `dream_test/suite`: Test suites
- `dream_test/matchers`: Matcher API
- `dream_test/types`: Shared data types
- `dream_test/runner`: Test execution
- `dream_test/unit`: describe/it DSL
- `dream_test/reporters/bdd`: Output formatting

---

## 6. Pipes Over Fluent Builders

**Rule**: Functions should take concrete arguments and return values—not return other functions for chaining.

**Why**: Pipe-first code is idiomatic Gleam. Avoiding currying keeps APIs straightforward.

#### ❌ Don't: a fluent, curried matcher <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/compile_errors/fluent_builder.gleam#L8-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn check(value: Int, expected: Int) {
  value
  |> should.be_equal(expected)
  |> or_fail_with("message")
}
```

Dream Test has no `should` module, so this code does not even compile. A test of the snippets project compiles it and checks what the compiler says:

#### The compiler error <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/compile_error_fluent_builder.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
error: Unknown module
   ┌─ build/compile_errors/fluent_builder/src/fluent_builder.gleam:10:6
   │
10 │   |> should.be_equal(expected)
   │      ^^^^^^

No module has been found with the name `should`.

```

#### ✅ Do: pipe-first <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/pipe_first_do.gleam#L7-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn check(value: Int, expected: Int) -> Result(AssertionResult, String) {
  value
  |> should
  |> be_equal(expected)
  |> or_fail_with("message")
}
```

---

## 7. Import Style

**Rule**: Use unqualified imports for DSL functions and piped helpers. Use qualified references when the namespace adds clarity.

**Why**: `should`, `equal()`, `or_fail_with()` read better unqualified in pipes. Module prefixes add noise for frequently-used functions.

### Importing values

#### ✅ Good: unqualified DSL imports <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_values_good.gleam#L1-L3"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ✅ Good: Unqualified for pipe-friendly DSL
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
```

#### ❌ Bad: a redundant alias <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_values_bad.gleam#L1-L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ❌ Bad: Redundant alias
import dream_test/matchers as should
```

### Importing types

Use the `type` keyword to import types (not constructors):

#### ✅ Good: an explicit type import <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_types_good.gleam#L1-L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ✅ Good: Explicit type import
import dream_test/types.{type Status, type TestResult}
```

#### ❌ Bad: a constructor import <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_types_bad.gleam#L1-L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ❌ Bad: This imports constructors, not types
import dream_test/types.{TestResult}
```

### Mixed imports

You can import both types and values:

#### A type and a value from one module <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_mixed.gleam#L1"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/types.{type TestResult, full_name}
```

This imports `TestResult` as a type and `full_name` as a function.

### Handling module name conflicts

When two modules have the same final name (e.g., `dream_test/types` and `dream_test/gherkin/types`), both would create a `types` module reference. Use a combination of type aliasing and module aliasing to resolve conflicts.

**Choose which to alias based on the file's subject**:

- The module most relevant to the file's purpose gets unqualified imports
- Secondary/supporting modules: alias conflicting types inline, alias the module for qualified access

For example, with `import some/primary/module.{type Feature, type Scenario}` and `import some/other/module.{type Feature as OtherFeature, type Step} as other_module`, `Feature` is the type of the primary module, `OtherFeature` is the aliased type of the secondary module, `Step` is a type of the secondary module with no conflict, and `other_module.something()` reaches the rest of the secondary module.

**Real example in a gherkin module**:

#### Two modules named `types` <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_conflict.gleam#L6-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Gherkin is the primary subject → unqualified
import dream_test/gherkin/steps.{type SuiteChild, Group, Scenarios}
import dream_test/gherkin/types.{type Feature, type Scenario}

// Core test types are supporting → alias the conflicting `Group`,
// alias the module (both modules are named `types`)
import dream_test/types.{type Node, Group as NodeGroup} as test_types

pub fn checkout_group(feature: Feature) -> SuiteChild(Nil) {
  Group(name: "Checkout", tags: [], tests: [Scenarios(feature)])
}

pub fn plain_group() -> Node(Nil) {
  NodeGroup(name: "plain", tags: [], children: [])
}

pub fn first_scenarios(feature: Feature) -> List(Scenario) {
  list.take(feature.scenarios, 1)
}

pub fn kind() -> test_types.TestKind {
  test_types.Unit
}

pub fn tests() {
  describe("STANDARDS.md rule 7: two modules named types", [
    it("builds a Gherkin group, a test tree group and a kind", fn() {
      // Arrange
      let feature =
        types.Feature(
          name: "Shop",
          source: None,
          description: None,
          tags: [],
          background: None,
          scenarios: [],
          rules: [],
        )

      // Act
      let values = #(checkout_group(feature), plain_group(), kind())

      // Assert
      values
      |> should
      |> be_equal(#(
        Group(name: "Checkout", tags: [], tests: [Scenarios(feature)]),
        NodeGroup(name: "plain", tags: [], children: []),
        test_types.Unit,
      ))
      |> or_fail_with("both groups and the kind should be made")
    }),
  ])
}
```

If there are no conflicting names, you can use unqualified imports from both without aliasing:

#### No conflicting names <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/import_no_conflict.gleam#L1-L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// ✅ No conflicts: unqualified from both
import dream_test/gherkin/types.{type Feature}
import dream_test/suite.{type TestSuite}

// Both Feature and TestSuite are unqualified
```

**Key points**:

1. **Prefer unqualified imports** — they read better in code
2. **Alias based on subject** — the file's primary domain gets unqualified; supporting modules get aliased
3. **Alias conflicting types inline** — use `type Foo as OtherFoo` for individual type conflicts
4. **Alias the module** — use `as module_name` when you need qualified access to the secondary module
5. **Import both type and constructor** — if a type has a constructor with the same name (e.g., `Tree`), import both: `type Tree, Tree`

❌ **Don't** use fully qualified references when unqualified would work:

#### ❌ Don't: noisy qualified references <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/qualified_references_bad.gleam#L9-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Bad: Noisy qualified references
pub fn nested_tree(
  name: String,
  nested: List(dream_types.Node(Nil)),
) -> dream_types.Tree(Nil) {
  let tree =
    dream_types.Tree(initial: Nil, name: name, tags: [], children: [
      dream_types.Group(name: "nested", tags: [], children: nested),
    ])
  tree
}
```

✅ **Do** use unqualified imports:

#### ✅ Do: unqualified references <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/qualified_references_good.gleam#L7-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Good: Clean unqualified usage
pub fn nested_tree(name: String, nested: List(Node(Nil))) -> Tree(Nil) {
  let tree =
    Tree(initial: Nil, name: name, tags: [], children: [
      Group(name: "nested", tags: [], children: nested),
    ])
  tree
}
```

---

## 8. Config Records for Multi-Parameter Functions

**Rule**: When a function has many parameters (especially of similar types), use a config record with named fields instead of a long positional parameter list.

**Why**: Named fields are self-documenting. They prevent argument reordering mistakes and make refactoring safer.

#### ❌ Don't: two `Int` parameters side by side <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/config_record_dont.gleam#L25-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn run_example(tree: Tree(Nil)) -> RunReport {
  // Two Ints side by side: a caller can swap them and still compile
  run_tree_parallel(4, 5000, tree)
}
```

#### ✅ Do: a config record <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/config_record_do.gleam#L10-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn run_example(tree: Tree(Nil)) -> RunReport {
  let config = ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)

  run_tree_parallel(config: config, tree: tree)
}
```

**Threshold**: If a function has 3+ parameters, or 2+ parameters of the same type, consider a config record.

---

## Gleam-Specific Notes

### Pattern matching blocks

In `case` expressions, multi-expression branches need curly braces:

#### A branch with curly braces <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/standards/case_blocks.gleam#L26-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn names_of_node(
  name_prefix: List(String),
  node: Node(Nil),
) -> List(List(String)) {
  case node {
    Test(name: name, ..) -> [full_name(groups: name_prefix, name: name)]

    Group(name: name, children: children, ..) -> {
      let new_prefix = list.append(name_prefix, [name])
      collect_test_names(new_prefix, children, [])
    }

    _ -> []
  }
}
```

### List operations

Use `list.append(left, right)` to combine lists. Gleam's `gleam/list` does not have `concat` in the way some languages do.

### Labeled arguments

Gleam supports labeled arguments only when the function is _defined_ with labeled parameters. You cannot add labels at a call site if the function was defined with positional parameters.

---

## Summary

These standards exist to make Dream Test predictable and debuggable. When in doubt:

1. **Be explicit** — pass data, don't capture it
2. **Be flat** — extract helpers, don't nest
3. **Be descriptive** — name things clearly
4. **Be consistent** — follow existing patterns

Standards evolve. If you think a rule should change, open an issue to discuss.
