## Assertions & matchers (the `should` pipeline)

If you’ve used Jest/RSpec style assertions before, this is the Dream Test equivalent — but pipe-first and composable.

Dream Test assertions are designed around a single, composable pattern:

### An assertion pipeline <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/matchers/equality.gleam#L7-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      2 + 3
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should equal 5")
```

Read it as a pipeline (top-to-bottom):

- Start from the value you’re checking.
- `should` starts an assertion chain.
- Each matcher either confirms something (“be_equal”) or unwraps something (“be_ok”, “be_some”).
- `or_fail_with(...)` attaches the message you’ll see when this fails.

### Why this pattern?

- **No macros, no hidden magic**: everything is ordinary Gleam code.
- **Composable**: matchers can unwrap values (like `Option`/`Result`) and pass the unwrapped value onward.
- **Consistent failures**: failures are structured values that reporters can format well.

There’s also a human reason:

- Assertions become part of your test’s narrative. A good pipeline reads like a sentence and fails with a message that tells you what matters.

### Chaining matchers (unwrap + assert)

#### Chain matchers <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/unit/chaining.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_ok, be_some, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Chaining matchers", [
    // Unwrap Some, then check the value
    it("unwraps Option", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("Should contain 42")
    }),
    // Unwrap Ok, then check the value
    it("unwraps Result", fn() {
      Ok("success")
      |> should
      |> be_ok()
      |> be_equal("success")
      |> or_fail_with("Should be Ok with 'success'")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### Built-in matcher catalogue (practical examples)

#### Built-in matchers <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/matchers/builtin_matchers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{
  be_between, be_equal, be_false, be_ok, be_some, be_true, contain,
  contain_string, have_length, match_regex, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Built-in matchers", [
    it("boolean: be_true", fn() {
      True
      |> should
      |> be_true()
      |> or_fail_with("expected True")
    }),
    it("boolean: be_false", fn() {
      False
      |> should
      |> be_false()
      |> or_fail_with("expected False")
    }),
    it("option: be_some + equal", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("expected Some(42)")
    }),
    it("result: be_ok + equal", fn() {
      Ok("hello")
      |> should
      |> be_ok()
      |> be_equal("hello")
      |> or_fail_with("expected Ok(\"hello\")")
    }),
    it("collection: have_length", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("expected list length 3")
    }),
    it("collection: contain", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("expected list to contain 2")
    }),
    it("comparison: be_between", fn() {
      5
      |> should
      |> be_between(1, 10)
      |> or_fail_with("expected 5 to be between 1 and 10")
    }),
    it("string: contain_string", fn() {
      "hello world"
      |> should
      |> contain_string("world")
      |> or_fail_with("expected substring match")
    }),
    it("string: match_regex", fn() {
      "user-123"
      |> should
      |> match_regex("^user-\\d+$")
      |> or_fail_with("expected an id like user-123")
    }),
  ])
}
```

### Built-in matchers (table)

All built-in matchers are re-exported from `dream_test/matchers` and are designed to be used in the `should |> matcher(...) |> or_fail_with(...)` pipeline.

| Category               | Matcher                        | What it asserts / does                                               |
| ---------------------- | ------------------------------ | -------------------------------------------------------------------- |
| **Equality**           | `be_equal(expected)`           | Structural equality (`==`).                                          |
| **Equality**           | `not_equal(unexpected)`        | Structural inequality (`!=`).                                        |
| **Boolean**            | `be_true()`                    | Value is `True`.                                                     |
| **Boolean**            | `be_false()`                   | Value is `False`.                                                    |
| **Option**             | `be_some()`                    | Value is `Some(_)` and **unwraps** to the inner value for chaining.  |
| **Option**             | `be_none()`                    | Value is `None`.                                                     |
| **Result**             | `be_ok()`                      | Value is `Ok(_)` and **unwraps** to the `Ok` value for chaining.     |
| **Result**             | `be_error()`                   | Value is `Error(_)` and **unwraps** to the error value for chaining. |
| **Collections (List)** | `contain(item)`                | List contains `item`.                                                |
| **Collections (List)** | `not_contain(item)`            | List does not contain `item`.                                        |
| **Collections (List)** | `have_length(n)`               | List length is exactly `n`.                                          |
| **Collections (List)** | `be_empty()`                   | List is empty (`[]`).                                                |
| **Comparison (Int)**   | `be_greater_than(n)`           | Value is `> n`.                                                      |
| **Comparison (Int)**   | `be_less_than(n)`              | Value is `< n`.                                                      |
| **Comparison (Int)**   | `be_at_least(n)`               | Value is `>= n`.                                                     |
| **Comparison (Int)**   | `be_at_most(n)`                | Value is `<= n`.                                                     |
| **Comparison (Int)**   | `be_between(min, max)`         | Value is strictly between: `min < value < max`.                      |
| **Comparison (Int)**   | `be_in_range(min, max)`        | Value is in inclusive range: `min <= value <= max`.                  |
| **Comparison (Float)** | `be_greater_than_float(n)`     | Value is `> n`.                                                      |
| **Comparison (Float)** | `be_less_than_float(n)`        | Value is `< n`.                                                      |
| **String**             | `start_with(prefix)`           | String starts with `prefix`.                                         |
| **String**             | `end_with(suffix)`             | String ends with `suffix`.                                           |
| **String**             | `contain_string(substring)`    | String contains `substring`.                                         |
| **String**             | `match_regex(pattern)`         | String matches a regular expression (`pattern`) anywhere within it.  |
| **Snapshot**           | `match_snapshot(path)`         | Compares a `String` to a snapshot file (creates it on first run).    |
| **Snapshot**           | `match_snapshot_inspect(path)` | Snapshot testing for any value via `string.inspect` serialization.   |

### Writing custom matchers (the matcher pattern)

Dream Test doesn’t require a special “custom matcher API.” Built-in and custom matchers follow the same simple pattern:

- A matcher is a function that **takes a `MatchResult(a)`** and **returns a `MatchResult(b)`**.
- If the incoming result is already a failure, the matcher should **propagate it unchanged**.
- Otherwise, it inspects the value and returns either `MatchOk(value)` or `MatchFailed(AssertionFailure(...))`.

Here’s a minimal custom matcher that checks “even number”:

#### An even-number matcher <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/matchers/custom_matchers.gleam#L5-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/types.{
  AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/option.{Some}
import gleam/string

/// A custom matcher that checks if an integer is even.
///
/// Matchers receive a `MatchResult(a)` and return a `MatchResult(b)`.
/// Most matchers keep the same type (a == b), but unwrapping matchers
/// like `be_some` change the type.
///
pub fn be_even(result) {
  case result {
    // If already failed, propagate the failure
    MatchFailed(failure) -> MatchFailed(failure)
    // Otherwise, check our condition
    MatchOk(value) -> check_even(value)
  }
}

fn check_even(value) {
  case value % 2 == 0 {
    True -> MatchOk(value)
    False ->
      MatchFailed(AssertionFailure(
        operator: "be_even",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(value),
          description: "expected an even number",
        )),
      ))
  }
}
```

This example uses a structured `payload` (`CustomMatcherFailure`) so reporters can display richer diagnostics without forcing you to bake everything into a string message.

### Why matchers unwrap values

The “unwrap then assert” flow is one of the biggest quality-of-life wins of the pipeline approach.

Instead of:

- Pattern matching in every test
- Copy/pasting error handling
- Producing unclear failures (“expected Ok(_) but got Error(_)”) without context

…you can write the story you mean: “this should be Ok, and the value should equal X.”

### Explicit success/failure (when branching is unavoidable)

Sometimes you need a conditional check that isn’t a good fit for the normal matcher pipeline.
Use `succeed()` and `fail_with("...")` to keep the return type consistent.

#### Explicit success and failure <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/unit/explicit_failures.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{fail_with, succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets.{divide}

pub fn tests() {
  describe("Explicit failures", [
    it("succeeds explicitly when division works", fn() {
      let result = divide(10, 2)
      Ok(case result {
        Ok(_) -> succeed()
        Error(_) -> fail_with("Should have succeeded")
      })
    }),
    it("fails explicitly when expecting an error", fn() {
      let result = divide(10, 0)
      Ok(case result {
        Ok(_) -> fail_with("Should have returned an error")
        Error(_) -> succeed()
      })
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### Common pitfalls (and how to avoid them)

- **Forgetting `or_fail_with(...)`**: without it, failures tend to be harder to interpret in CI logs. Treat it like part of the assertion, not an optional extra.
- **Asserting too much in one chain**: long chains can hide which step mattered. Split into smaller checks when it improves clarity.
- **Using snapshots where equality is clearer**: if a value is tiny, prefer `be_equal(...)` over snapshot matchers (see the snapshot chapter for the tradeoff).

### What's Next?

- Go back to [Context-aware unit tests](04-context-aware-tests.md)
- Go back to [Documentation README](README.md)
- Continue to [Lifecycle hooks](06-lifecycle-hooks.md)
