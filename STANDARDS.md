# dream_test Coding Standards

This document captures the core coding standards for the `dream_test` project. These are intended to keep the codebase predictable, debuggable, and easy to evolve over time.

The standards below are **project conventions**, not general Gleam rules. They may be stricter than typical Gleam style, but they align with how we want to reason about this framework.

## 1. No Nested `case` Expressions

**Rule**
- Do not nest `case` expressions inside each other.
- Prefer a single `case` per function or per small helper, and factor nested logic into pure helper functions.

**Rationale**
- Deeply nested pattern matches become hard to read, reason about, and test.
- Flattening logic into named helpers:
  - Makes control flow explicit.
  - Encourages small, composable functions.
  - Improves error messages and stack traces when something goes wrong.

**Example (discouraged)**

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

**Example (preferred)**

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

## 2. No Closures

**Rule**
- Do not use closures (functions that capture variables from an outer scope) in the library code.
- All functions should be defined at the module level with explicit parameters.

**Rationale**
- Closures hide dependencies in captured scope, making functions harder to test and reason about.
- Explicit parameters:
  - Make data and dependencies obvious at call sites.
  - Avoid surprises when refactoring or moving code.
  - Align with a service/context style where all dependencies are passed in.

**Example (discouraged)**

```gleam
fn make_checker(limit) {
  fn(value) {
    value < limit
  }
}
```

**Example (preferred)**

```gleam
pub fn is_less_than(limit, value) {
  value < limit
}
```

If you need to “configure” behavior, prefer a small data type or explicit parameter rather than a closure.

## 3. No Anonymous Functions in Library Code

**Rule**
- Do not use anonymous functions (`fn(...) { ... }`) in library modules.
- Every function should have a **name** and be defined at the top level of its module.
- Anonymous functions may be acceptable in very small bootstrap or script code, but should generally be avoided there too.

**Rationale**
- Named functions:
  - Show up clearly in stack traces and logs.
  - Are easier to search for and reuse.
  - Encourage reusability and testing in isolation.
- Anonymous functions often encourage “inline cleverness” rather than clear structure.

**Example (discouraged)**

```gleam
describe("math", [
  it("adds numbers", fn(context) {
    1 + 2
  }),
])
```

**Example (preferred)**

```gleam
pub fn math_tests() {
  describe("math", [
    it("adds numbers", math_adds_numbers),
  ])
}

fn math_adds_numbers(context) {
  1 + 2
}
```

Even when a function is used in only one place, giving it a name improves clarity and makes it easier to expand later.

## 4. No Abbreviated Identifiers for Core Concepts

**Rule**
- Do not abbreviate important identifiers like `context`, `failure`, `result`, etc.
- Use full, descriptive names instead of short forms like `ctx`, `res`, `f`, etc.

**Rationale**
- Descriptive names reduce cognitive load when reading code.
- They help new contributors and future-you understand what a value represents without jumping around the file.

**Example (discouraged)**

```gleam
pub fn add_failure(ctx, f) {
  TestContext(failures: [f, ..ctx.failures])
}
```

**Example (preferred)**

```gleam
pub fn add_failure(context, failure) {
  TestContext(failures: [failure, ..context.failures])
}
```

## 5. Directory and Module Naming

**Rule**
- Do not use reserved words (like `assert`) in directory or module names.
- Prefer clear, descriptive module paths such as:
  - `dream_test/assertions/context`
  - `dream_test/assertions/should`
  - `dream_test/core/types`
  - `dream_test/bootstrap/bootstrap_core_assert`

**Rationale**
- Avoiding reserved words prevents confusing syntax errors.
- Consistent naming (e.g. `bootstrap_` prefix) keeps related modules grouped and discoverable.

## 6. Pipes Over Fluent Builders

**Rule**
- Prefer simple pipe-first function usage over fluent/builder-style APIs.
- Functions should take concrete arguments and return values, not return other functions for chaining.

**Rationale**
- Pipe-first Gleam code is easier to read and aligns with the language’s idioms.
- Avoiding currying and fluent builders keeps APIs straightforward and debuggable.

**Example (preferred)**

```gleam
value
|> should.equal(context, expected)
|> should.or_fail_with("message")
```

**Discouraged**

```gleam
value
|> should.equal(expected)(context)
|> should.or_fail_with("message")
```

## 7. Import Style for Piped Helpers

**Rule**
- In Gleam, when you import specific values from a module using `{...}`, the module name itself is also brought into scope.
-  - For example, `import some/example/module_name.{do_something}` imports both `module_name` and `do_something`.
- Use **qualified imports** for primary namespaces (e.g. `should.equal`, `gherkin.define_step`).
- Use **unqualified imports** for small, piped helpers that act on a value or context, such as `or_fail_with`.
- Use **unqualified imports** for core types when the module name does not add clarity.
  - Prefer the explicit type-import syntax, for example:
    - `import dream_test/assertions/context.{type TestContext, add_failure}`
    - Then use `TestContext` and `add_failure` directly in the module.
- This means a typical test file will:
  - Call `should.equal` when introducing an assertion.
  - Pipe into `or_fail_with` imported unqualified for readability.
  - Refer to `TestContext` directly via a `{type ...}` import when the meaning is obvious.

**Rationale**
- Keeping `should.equal` qualified makes the origin of the main assertion clear.
- Dropping the module prefix for piped, context-transforming helpers improves readability and reduces visual noise.
- This mirrors how many frameworks distinguish between core namespaces and small utility functions.

**Example (preferred)**

```gleam
import dream_test/assertions/should.{or_fail_with}

value
|> should.equal(context, expected)
|> or_fail_with("message")
```

**Discouraged**

```gleam
import dream_test/assertions/should as should

value
|> should.equal(context, expected)
|> should.or_fail_with("message")
```

## 8. Named Arguments & Config Records

**Rule**
- When a function conceptually has many parameters (especially of similar types), prefer a **config record** with named fields over a long positional parameter list.
- For simpler functions with only one or two parameters, positional arguments are acceptable.

**Rationale**
- Named fields on a config record make construction sites self-documenting.
- They reduce errors from argument reordering and make refactors safer.
- They are particularly important in a test framework, where functions often accept many configuration options.

**Example (preferred)**

```gleam
let config = SingleTestConfig(
  name: "passing test",
  full_name: ["bootstrap", "runner_core"],
  tags: ["bootstrap", "runner"],
  kind: types.Unit,
  location: location,
  run: passing_test,
)

run_single_test(config)
```

**Discouraged**

```gleam
run_single_test("passing test", full_name, tags, types.Unit, location, passing_test)
```

---

These standards are living guidelines. As the project evolves, we may refine them, but any changes should maintain the same goals: clarity, explicitness, and ease of reasoning about the behavior of the test framework.
