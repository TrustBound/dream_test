# Coding Standards

This document defines the coding conventions for Dream Test. These are **project-specific rules**, not general Gleam guidelines—they may be stricter than typical Gleam style.

**Goals**: clarity, explicitness, debuggability.

---

## Quick Reference

| Rule                                                                | Summary                                          |
| ------------------------------------------------------------------- | ------------------------------------------------ |
| [No nested `case`](#1-no-nested-case-expressions)                   | One `case` per function; extract helpers         |
| [No closures](#2-no-closures)                                       | All functions defined at module level            |
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

❌ **Don't**

```gleam
case value1 {
  Some(x) ->
    case value2 {
      Ok(y) -> do_something(x, y)
      Error(e) -> handle_error(e)
    }
  None -> handle_none()
}
```

✅ **Do**

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

❌ **Don't**

```gleam
fn make_checker(limit) {
  fn(value) { value < limit }
}
```

✅ **Do**

```gleam
pub fn is_less_than(limit, value) {
  value < limit
}
```

If you need configurable behavior, use a data type or explicit parameter—not a closure.

---

## 3. No Anonymous Functions in Library Code

**Rule**: Every function must have a name and be defined at the top level. No inline `fn(...) { ... }` in library modules.

**Why**: Named functions appear in stack traces, are searchable, and encourage reuse. Anonymous functions encourage "inline cleverness."

❌ **Don't**

```gleam
describe("math", [
  it("adds numbers", fn() { 1 + 2 }),
])
```

✅ **Do**

```gleam
pub fn math_tests() {
  describe("math", [
    it("adds numbers", adds_numbers_test),
  ])
}

fn adds_numbers_test() {
  1 + 2
}
```

**Exception**: Test files may use anonymous functions for simple inline test bodies (as shown in the README examples). Library code (under `src/`) must not.

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

❌ **Don't**

```gleam
pub fn add_failure(ctx, f) {
  TestContext(failures: [f, ..ctx.failures])
}
```

✅ **Do**

```gleam
pub fn add_failure(context, failure) {
  TestContext(failures: [failure, ..context.failures])
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

```
dream_test/context         # Per-test state
dream_test/matchers        # Matcher API
dream_test/types           # Shared data types
dream_test/runner          # Test execution
dream_test/unit            # describe/it DSL
dream_test/reporters/bdd    # Output formatting
```

---

## 6. Pipes Over Fluent Builders

**Rule**: Functions should take concrete arguments and return values—not return other functions for chaining.

**Why**: Pipe-first code is idiomatic Gleam. Avoiding currying keeps APIs straightforward.

❌ **Don't** (fluent/curried)

```gleam
value
|> should.be_equal(expected)
|> or_fail_with("message")
```

✅ **Do** (pipe-first)

```gleam
value
|> should
|> be_equal(expected)
|> or_fail_with("message")
```

---

## 7. Import Style

**Rule**: Use unqualified imports for DSL functions and piped helpers. Use qualified references when the namespace adds clarity.

**Why**: `should`, `equal()`, `or_fail_with()` read better unqualified in pipes. Module prefixes add noise for frequently-used functions.

### Importing values

```gleam
// ✅ Good: Unqualified for pipe-friendly DSL
import dream_test/unit.{describe, it}
import dream_test/matchers.{should, be_equal, or_fail_with}

// ❌ Bad: Redundant alias
import dream_test/matchers as should
```

### Importing types

Use the `type` keyword to import types (not constructors):

```gleam
// ✅ Good: Explicit type import
import dream_test/types.{type TestResult, type Status}

// ❌ Bad: This imports constructors, not types
import dream_test/types.{TestResult}
```

### Mixed imports

You can import both types and values:

```gleam
import dream_test/context.{type TestContext, add_failure}
```

This imports `TestContext` as a type and `add_failure` as a function.

### Handling module name conflicts

When two modules have the same final name (e.g., `dream_test/types` and `dream_test/gherkin/types`), both would create a `types` module reference. Use a combination of type aliasing and module aliasing to resolve conflicts.

**Choose which to alias based on the file's subject**:

- The module most relevant to the file's purpose gets unqualified imports
- Secondary/supporting modules: alias conflicting types inline, alias the module for qualified access

```gleam
// Primary module: unqualified imports
import some/primary/module.{type Feature, type Scenario}

// Secondary module: alias conflicting types, alias module for qualified access
import some/other/module.{
  type Feature as OtherFeature, type Step,
} as other_module

// Now you can use:
let feature: Feature = ...           // from primary
let other: OtherFeature = ...        // aliased type from secondary
let step: Step = ...                 // non-conflicting from secondary
let thing = other_module.something() // qualified access to secondary
```

**Real example in a gherkin module**:

```gleam
// Gherkin types are the primary subject → unqualified
import dream_test/gherkin/types.{type Feature, type Scenario}

// Core test types are supporting → alias conflicts, alias module
import dream_test/types.{
  type TestSuite, TestSuite, SuiteGroup,
} as test_types

let feature: Feature = ...
let suite = TestSuite(name: "test", items: [SuiteGroup(...)])
```

If there are no conflicting names, you can use unqualified imports from both without aliasing:

```gleam
// ✅ No conflicts: unqualified from both
import dream_test/gherkin/types.{type Feature}
import dream_test/types.{type TestSuite, TestSuite}

// Both Feature and TestSuite are unqualified
```

**Key points**:

1. **Prefer unqualified imports** — they read better in code
2. **Alias based on subject** — the file's primary domain gets unqualified; supporting modules get aliased
3. **Alias conflicting types inline** — use `type Foo as OtherFoo` for individual type conflicts
4. **Alias the module** — use `as module_name` when you need qualified access to the secondary module
5. **Import both type and constructor** — if a type has a constructor with the same name (e.g., `TestSuite`), import both: `type TestSuite, TestSuite`

❌ **Don't** use fully qualified references when unqualified would work:

```gleam
// Bad: Noisy qualified references
let suite = dream_types.TestSuite(
  name: name,
  items: dream_types.SuiteGroup(nested),
)
```

✅ **Do** use unqualified imports:

```gleam
// Good: Clean unqualified usage
let suite = TestSuite(
  name: name,
  items: SuiteGroup(nested),
)
```

---

## 8. Config Records for Multi-Parameter Functions

**Rule**: When a function has many parameters (especially of similar types), use a config record with named fields instead of a long positional parameter list.

**Why**: Named fields are self-documenting. They prevent argument reordering mistakes and make refactoring safer.

❌ **Don't**

```gleam
run_single_test("passing test", full_name, tags, types.Unit, passing_test)
```

✅ **Do**

```gleam
let config = SingleTestConfig(
  name: "passing test",
  full_name: ["bootstrap", "runner_core"],
  tags: ["bootstrap", "runner"],
  kind: types.Unit,
  run: passing_test,
)

run_single_test(config)
```

**Threshold**: If a function has 3+ parameters, or 2+ parameters of the same type, consider a config record.

---

## Gleam-Specific Notes

### Pattern matching blocks

In `case` expressions, multi-expression branches need curly braces:

```gleam
case node {
  ItTest(name, run) ->
    build_it_test_case(...)

  DescribeGroup(name, children) -> {
    let new_prefix = list.append(name_prefix, [name])
    to_test_cases_from_list(module_name, new_prefix, children, accumulated)
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
