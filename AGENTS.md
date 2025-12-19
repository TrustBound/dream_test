# AGENTS notes for Dream Test

This file is a reminder of things the AI agent (and future maintainers) tends to get wrong or forget, especially around Gleam and this codebase.

It is **not** user-facing documentation. It exists to reduce repeated mistakes.

## 1. Gleam Functions & Named Arguments

- Gleam **does** support labeled/named arguments, but **only** when the function is defined with labeled parameters.
- If a function is defined with positional parameters, you cannot add labels at the call site.
- For complex, multi-parameter APIs in this project, we prefer **config records** with named fields rather than long positional argument lists.
  - Example (preferred):
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

## 2. Imports & Namespaces

- In Gleam, importing specific names from a module using `{...}` **also** brings the module name into scope.
  - `import dream_test/unit.{describe, it}` imports `unit` and the unqualified values `describe` and `it`.
  - `import dream_test/matchers.{or_fail_with}` imports `matchers` and the unqualified value `or_fail_with`, so `matchers.be_equal` and `or_fail_with(...)` are both valid.
- Only use `as` when you genuinely need to distinguish between two different modules with the **same** final name.
  - Do **not** write `import dream_test/matchers as should`; it adds no information and is banned in this project.
- To avoid duplicate imports and confusion, follow the project standards:
  - Use unqualified imports for:
    - `describe`, `it` from `dream_test/unit`.
    - Piped helpers like `or_fail_with` from `dream_test/matchers`.
    - Core types via `{type ...}` imports when the module name adds no clarity.

## 3. Type Imports

- To import a **type** unqualified, use the `type` syntax:
  - `import dream_test/context.{type TestContext, add_failure}`
  - Then use `TestContext` and `add_failure` directly.
- Importing a constructor or value without `type` does **not** make it available as a type.
  - If you see "There is a value in scope with the name X, but no type in scope with that name", you probably forgot `type`.

## 4. Reserved Words & Module Names

- `assert` is a **reserved word** in Gleam.
  - Do **not** use it as a directory or module name (e.g. `dream_test/assert`).
  - Use `matchers` instead (e.g. `dream_test/matchers`).

## 5. Pattern Matching & Blocks

- In `case` expressions, each branch must return an expression. If multiple expressions are needed, wrap them in `{ ... }`.
  - Example:
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
- Forgetting `{ .. }` around multiple expressions in a branch leads to syntax errors like "I was expecting an expression after this".

## 6. List Helpers

- `gleam/list` does **not** have `concat` the way some other languages do.
  - Use `list.append(left, right)` to append one list to another.
  - For prefixing, something like `list.append(name_prefix, [name])` is appropriate.

## 7. Avoid Currying & Fluent APIs

- Do **not** return functions from assertion helpers for general chaining.
  - This project prefers simple, multi-argument functions that are pipe-friendly.
- Correct pattern for assertions:
  - `value |> should |> be_equal(expected) |> or_fail_with("message")`
  - Not: `value |> should.be_equal(expected)` (old pattern without chaining).

## 8. No Closures, No Anonymous Functions

- Project standard: no closures capturing outer scope in library code.
- No anonymous `fn` in library modules; every function should be named and top-level.
- When tempted to use an inline anonymous function, instead define a small named helper.

## 9. Check STANDARDS.md Before Designing APIs

- Before introducing new modules, types, or APIs, re-read `STANDARDS.md` to:
  - Avoid nested `case` expressions.
  - Use config records for multi-parameter functions.
  - Keep imports and naming consistent (no `ctx`, `res`, etc.).
  - Use unqualified imports where they improve readability.

## 10. When Unsure About Gleam Semantics

- Do **not** guess about core language or standard library behavior.
- Instead:
  - Consult the Gleam tour or official docs.
  - Or write a tiny bootstrap/experiment module to compile and run.
- Examples of things worth double-checking:
  - Exact names and signatures of `gleam/list` functions.
  - Import syntax for `{type ...}` and mixed type/value imports.
  - How labeled arguments interact with function definitions.

This file should grow over time as more recurring pitfalls are discovered. The goal is to fail less noisily and keep the code and knowledge around it aligned.